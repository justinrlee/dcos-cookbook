#
# Cookbook Name:: dcos
# Recipe:: _ip-detect
#
# Copyright 2016, Chef Software, Inc.
#
# License TBD

# Default is 'online'; if not 'online, it is assumed that the user has specified two keys'
if node['dcos']['fault-domain-detect'] == 'online'
  remote_file '/usr/src/dcos/genconf/fault-domain-detect' do
    # Pull latest from GitHub
    source 'https://raw.githubusercontent.com/dcos/dcos/master/gen/fault-domain-detect/cloud.sh'
    mode '0755'
  end
  
else
  template '/usr/src/dcos/genconf/fault-domain-detect' do
    region = node['dcos']['fault-domain-detect']['region']
    zone = node['dcos']['fault-domain-detect']['zone']
    source 'fault-domain-detect.erb'
    mode '0755'
    variables(region: region, zone: zone)
  end
end