# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# !!! PLEASE KEEP THIS SCRIPT IDEMPOTENT !!!
#

require 'util/password'

AppConfig.use_cp = false if ENV['NO_CP']
AppConfig.use_pulp = false if ENV['NO_PULP']

def format_errors model=nil
  return '(nil found)' if model.nil?
  model.errors.full_messages.join(';')
end

# create basic roles
superadmin_role = Role.find_or_create_by_name(
  :name => 'Administrator', 
  :description => 'Super administrator with all access.')
raise "Unable to create super-admin role: #{format_errors superadmin_role}" if superadmin_role.nil? or superadmin_role.errors.size > 0

superadmin_role_perm = Permission.find_or_create_by_name(:name=> "super-admin-perm", :role => superadmin_role, :all_types => true)
raise "Unable to create super-admin role permission: #{format_errors superadmin_role_perm}" if superadmin_role_perm.nil? or superadmin_role_perm.errors.size > 0

# create read *everything* role and assign permissions to it
reader_role = Role.make_readonly_role('Read Everything')
raise "Unable to create reader role: #{format_errors reader_role}" if reader_role.nil? || reader_role.errors.size > 0

# create the super admin if none exist - it must be created before any statement in the seed.rb script
User.current = user_admin = User.find_by_username('admin')
unless user_admin
  user_admin = User.new(
  :roles => [ superadmin_role ],
  :username => 'admin',
  :password => 'admin',
  :email => 'root@localhost')
  User.current = user_admin
  user_admin.save!
end
raise "Unable to create admin user: #{format_errors user_admin}" if user_admin.nil? or user_admin.errors.size > 0

# create the default org = "admin" if none exist
first_org = Organization.find_or_create_by_name(:name => "ACME_Corporation", :description => "ACME Corporation Organization", :cp_key => 'ACME_Corporation')
raise "Unable to create first org: #{format_errors first_org}" if first_org and first_org.errors.size > 0
raise "Are you sure you cleared candlepin?! Unable to create first org!" if first_org.environments.nil?

#create a provider
if Provider.count == 0
  porkchop = Provider.create!({
      :name => 'Custom Provider 1',
      :organization => first_org,
      :repository_url => 'http://download.fedoraproject.org/pub/fedora/linux/releases/',
      :provider_type => Provider::CUSTOM
  })

  Provider.create!({
      :name => 'Red Hat',
      :organization => first_org,
      :repository_url => 'https://somehost.example.com/content/',
      :provider_type => Provider::REDHAT
  })
end
