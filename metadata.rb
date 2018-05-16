name             'dcos'
maintainer       'Chef Software, Inc.'
maintainer_email 'partnereng@chef.io'
license          'Apache-2.0'
description      'Installs/Configures Mesosphere DC/OS'
long_description 'Installs/Configures Mesosphere DC/OS'
version          '1.2.6'

source_url 'https://github.com/chef-partners/dcos-cookbook' if
  respond_to?(:source_url)
issues_url 'https://github.com/chef-partners/dcos-cookbook/issues' if
  respond_to?(:issues_url)
chef_version '>= 12.1' if
  respond_to?(:chef_version)

%w(
  centos
  oracle
  redhat
  scientific
).each do |distro|
  supports distro
end

depends 'chef-yum-docker', '~> 3.0.0'
depends 'docker', '~> 4.2.0'
depends 'selinux', '~> 2.1.0'
