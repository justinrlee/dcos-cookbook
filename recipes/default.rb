#
# Cookbook Name:: dcos
# Recipe:: default
#
# Copyright 2016, Chef Software, Inc.
# Copyright 2017-2018 Chris Gianelloni
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Prereqs
include_recipe 'selinux::permissive'

%w(
  firewalld
  rsyslog
).each do |svc|
  service svc do
    action %i(stop disable)
  end
end

package %w(
  curl
  ipset
  tar
  unzip
  xz
  net-tools
)

group 'nogroup'

include_recipe 'chef-yum-docker' if node['dcos']['manage_docker']

# Install docker with overlayfs
docker_service 'default' do
  storage_driver node['dcos']['docker_storage_driver']
  version node['dcos']['docker_version'] if node['dcos']['docker_version']
  install_method 'package' if node['dcos']['docker_version']
  action %i(create start)
  only_if { node['dcos']['manage_docker'] }
end

directory '/usr/src/dcos/genconf' do
  mode '0755'
  recursive true
end

# All local files should be generated / created prior to downloading DC/OS.
# Only used on DC/OS Enterprise 1.11+
file '/usr/src/dcos/genconf/license.txt' do
  content node['dcos']['dcos_license_text']
  sensitive true
  only_if { dcos_enterprise? && node['dcos']['dcos_version'].to_f >= 1.11 }
end

template '/usr/src/dcos/genconf/config.yaml' do
  source 'config.yaml.erb'
  variables config: node['dcos']['config']
end

# Only supported on DC/OS Enterprise 1.11+
include_recipe 'dcos::_fault_domain_detect' if dcos_enterprise? && node['dcos']['dcos_version'].to_f >= 1.11

# generate the genconf/ip-detect script
include_recipe 'dcos::_ip-detect'

remote_file '/usr/src/dcos/dcos_generate_config.sh' do
  source dcos_generate_config_url
  mode '0755'
end

# Need better logic to determine when to run / not run this.
execute 'dcos-genconf' do
  command '/usr/src/dcos/dcos_generate_config.sh --genconf'
  user 'root'
  cwd '/usr/src/dcos'
  # creates '/usr/src/dcos/genconf/cluster_packages.json' # Breaks upgrades
end

file '/usr/src/dcos/genconf/serve/dcos_install.sh' do
  mode '0755'
end

# We're going to poll this up to 30 times, to prevent issues where a port may temporarily be in use
execute 'preflight-check' do
  command "/usr/src/dcos/genconf/serve/dcos_install.sh --preflight-only #{node['dcos']['dcos_role']}"
  retry_delay 1
  retries 30
  action :run
  not_if { ::File.exist?('/opt/mesosphere/environment') } # assume DC/OS is installed
end

execute 'dcos_install' do
  command "/usr/src/dcos/genconf/serve/dcos_install.sh #{node['dcos']['dcos_role']}"
  creates '/opt/mesosphere/environment'
  user 'root'
  cwd '/usr/src/dcos'
  action :run
end

# Poll for leader.mesos to ensure we're up before finishing converge
execute 'check-mesos-up' do
  command 'ping -c1 leader.mesos'
  retry_delay 1
  retries node['dcos']['leader_check_retries']
  action :run
  not_if 'ping -c1 leader.mesos'
end

execute 'check-marathon-up' do
  command 'ping -c1 marathon.mesos'
  retry_delay 1
  retries node['dcos']['leader_check_retries']
  action :run
  not_if 'ping -c1 marathon.mesos'
end
