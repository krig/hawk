# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "hawk"
  config.vm.box_url = "http://w3.suse.de/~tboerger/vagrant/sles12-sp0-minimal-virtualbox-0.0.1.box"

  config.bindfs.enabled = true
  config.bindfs.bind_folder "/vagrant", "/vagrant", force_group: "users"

  config.vm.define :webui, default: true do |machine|
    machine.vm.hostname = "hawk"

    machine.vm.network "forwarded_port", guest: 22, host: 3022
    machine.vm.network "forwarded_port", guest: 3000, host: 3000

    machine.vm.synced_folder ".", "/vagrant", type: "nfs"



    # config.vm.provision "chef_solo" do |chef|
    #   chef.cookbooks_path = "../my-recipes/cookbooks"
    #   chef.roles_path = "../my-recipes/roles"
    #   chef.data_bags_path = "../my-recipes/data_bags"
    #
    #   chef.add_recipe "mysql"
    #   chef.add_role "web"
    #
    #   chef.json = { mysql_password: "foo" }
    # end



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
