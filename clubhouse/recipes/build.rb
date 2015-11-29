#
# LOG NODE ATTRIBUTES
#

[
  "hostname", "fqdn", "domain", "ipaddress", "macaddress", "ip6address",
  "platform", "platform_version", "platform_family",
  "os", "os_version", "memory", "filesystem", "block_device", "cpu", "ebs",
  "uptime_seconds","uptime","idletime_seconds","idletime",
  "current_user","ssh_users","sudoers",
  "cloud","deploy","test_suite",
  "packages","recipes","roles","chef_environment","chef_packages","opsworks_custom_cookbooks",
  "mysql"
].each do |k|
  log "#{k}: #{node[k]}"
end

unless node.platform == "amazon"
  ["/home", "/home/ec2-user"].each do |aws_directory|
    directory aws_directory
  end

  node["ssh_users"].each do |id, member|
    directory "/home/#{member["name"]}"
  end
end

node["ssh_users"].each do |id, member|
  ["inbox","outbox"].each do |dir_name|
    directory "/home/#{member["name"]}/#{dir_name}" do
      owner member["name"] if node.platform == "amazon" # temporary workaround; todo: create users on non-amazon platforms
      group member["name"] if node.platform == "amazon" # temporary workaround; todo: create users on non-amazon platforms
      #mode '0755'
      #recursive true
      action :create
    end
  end

  template "secret message for #{member["name"]}" do
    path "/home/#{member["name"]}/inbox/secret_message.txt"
    source "secret_message.erb"
    variables({
      :member_name => member["name"],
      :passcode => "4d782a10037fbcd8cee463865cf54497", #todo: require 'digest' Digest::MD5.hexdigest("my phrase" + "1234")
      :passphrase => "#RaiseHigh the Buff and Blue"
    })
  end

  template "include root password in mysql configuration file for passwordless logs" do
    path "/etc/my.cnf"
    source "my.cnf.erb"
    owner "root"
    group "root"
  end

  bash "mysql setup for #{member["name"]}" do
    user node.platform == "amazon" ? 'ec2-user' : "vagrant" # temporary workaround; todo: create users on non-amazon platforms
    code <<-EOH
      mysql -uroot -e "DROP DATABASE IF EXISTS #{member["name"]};"
      mysql -uroot -e "CREATE DATABASE #{member["name"]};"
      mysql -uroot -e "GRANT ALL ON #{member["name"]}.* TO '#{member["name"]}'@'127.0.0.1' IDENTIFIED BY '#{member["mysql_password"]}';"
    EOH
  end
end

#todo: how to debug interactive node convergences like binding.pry?
#breakpoint 'name' do
#  action :break
#end
