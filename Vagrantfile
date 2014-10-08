# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "hawk"
  config.vm.box_url = "http://w3.suse.de/~tboerger/vagrant/sles12-sp0-minimal-virtualbox-0.0.1.box"

  config.omnibus.chef_version = :latest
  config.librarian_chef.cheffile_dir = "chef"

  config.vm.define :webui, default: true do |machine|
    machine.vm.hostname = "webui"

    machine.vm.network "forwarded_port", guest: 22, host: 3022
    machine.vm.network "forwarded_port", guest: 3000, host: 3000

    machine.vm.synced_folder ".", "/vagrant", type: "nfs"
    machine.bindfs.bind_folder "/vagrant", "/vagrant", force_group: "users"

    machine.vm.provision :chef_solo do |chef|
      chef.cookbooks_path = ["chef/cookbooks", "chef/site"]
      chef.roles_path = "chef/roles"
      chef.data_bags_path = "chef/data_bags"
      chef.custom_config_path = "chef/solo.rb"
      chef.synced_folder_type = "rsync"

      chef.add_recipe "zypper"
      chef.add_recipe "build"
      chef.add_recipe "git"
      chef.add_recipe "locales"
      chef.add_recipe "hawk"

      chef.json = {
        zypper: {
          repos: [
            {
              title: "SLE 12 Server",
              alias: "dist-12.0-server",
              uri: "http://dist.suse.de/install/SLP/SLE-12-Server-LATEST/x86_64/DVD1/",
              key: "http://dist.suse.de/install/SLP/SLE-12-Server-LATEST/x86_64/DVD1/content.key"
            },
            {
              title: "SLE 12 SDK",
              alias: "dist-12.0-sdk",
              uri: "http://dist.suse.de/install/SLP/SLE-12-SDK-LATEST/x86_64/DVD1/",
              key: "http://dist.suse.de/install/SLP/SLE-12-SDK-LATEST/x86_64/DVD1/content.key"
            },
            {
              title: "SLE 12 HA",
              alias: "dist-12.0-ha",
              uri: "http://dist.suse.de/install/SLP/SLE-12-HA-LATEST/x86_64/CD1/",
              key: "http://dist.suse.de/install/SLP/SLE-12-HA-LATEST/x86_64/CD1/content.key"
            }
          ]
        },
        git: {
          zypper: {
            enabled: false
          }
        }
      }
    end
  end

  config.vm.provider :virtualbox do |provider, override|
    provider.memory = 2048
    provider.cpus = 4

    override.vm.box_url = "http://w3.suse.de/~tboerger/vagrant/sles12-sp0-minimal-virtualbox-0.0.1.box"
  end

  config.vm.provider :libvirt do |provider, override|
    provider.host = "localhost"
    provider.username = "root"
    provider.password = "linux"
    provider.storage_pool_name = "default"
    provider.connect_via_ssh = true

    provider.memory = 2048
    provider.cpus = 4
    provider.nested = true

    override.vm.box_url = "http://w3.suse.de/~tboerger/vagrant/sles12-sp0-minimal-libvirt-0.0.1.box"
  end
end
