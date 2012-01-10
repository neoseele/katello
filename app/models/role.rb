#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

class Role < ActiveRecord::Base
  include Authorization
  include IndexedModel

  index_options :extended_json=>:extended_index_attrs, :json=>{:except=>[]}

  mapping do
    indexes :name_sort, :type => 'string', :index => :not_analyzed
  end



  acts_as_reportable

  has_many :roles_users
  has_many :users, :through => :roles_users
  has_many :permissions, :dependent => :destroy,:inverse_of =>:role, :class_name=>"Permission"
  has_one :owner, :class_name => 'User', :foreign_key => "own_role_id"
  has_many :search_tags, :class_name => 'Tag'
  has_many :search_verbs, :class_name => 'Verb'
  has_many :resource_types, :through => :permissions

  # scope to facilitate retrieving roles that are 'non-self' roles... group() so that unique roles are returned
  scope :non_self, joins("left outer join users on users.own_role_id = roles.id").where('users.own_role_id'=>nil).order('roles.name')

  validates :name, :uniqueness => true, :katello_name_format => true, :presence => true
  validates :description, :katello_description_format => true
  #validates_associated :permissions
  accepts_nested_attributes_for :permissions, :allow_destroy => true

  # scope for use by auto_complete_search to only show readable non-self roles
  scope :completer_scope, lambda {self.readable.non_self}

  scoped_search :on => :name, :complete_value => true, :rename => :'role.name'
  scoped_search :in => :resource_types, :on => :name, :complete_value => true, :ext_method => :search_by_type, :only_explicit => true, :rename => :'permission.type'
  scoped_search :in => :search_verbs, :on => :verb, :complete_value => true, :ext_method => :search_by_verb, :only_explicit => true, :rename => :'permission.verb'

  def self.search_by_verb(key, operator, value)
    permissions = Permission.all(:conditions => "verbs.verb #{operator} '#{value_to_sql(operator, value)}'", :include => :verbs)
    roles = permissions.map(&:role)
    opts  = roles.empty? ? "= 'nil'" : "IN (#{roles.map(&:id).join(',')})"

    return {:conditions => " roles.id #{opts} " }
  end

  def self.search_by_type(key, operator, value)
    permissions = Permission.all(:conditions => "resource_types.name #{operator} '#{value_to_sql(operator, value)}'", :include => :resource_type)
    roles = permissions.map(&:role)
    opts  = roles.empty? ? "= 'nil'" : "IN (#{roles.map(&:id).join(',')})"

    return {:conditions => " roles.id #{opts} " }
  end

  def self.value_to_sql(operator, value)
    return value if (operator !~ /LIKE/i)
    return (value =~ /%|\*/) ? value.tr_s('%*', '%') : "%#{value}%"
  end

  def self.non_self_roles
    #gotta be a better way to do this, but others wouldn't work
    Role.all(:conditions=>{"users.own_role_id"=>nil}, :include=> :owner)
  end

  def self_role_for_user
    User.where(:own_role_id => self.id).first
  end

  def self.make_readonly_role name, organization = nil
    #nil for organization implies all orgs
    role = Role.find_or_create_by_name(
            :name => name, :description => 'Read only role.')
    resource_perms = {}
    ResourceType::TYPES.keys.each do |key|
      resource_perms[key] = ResourceType.model_for(key).read_verbs if key.to_s != "all"
    end

    resource_perms.each_pair do |key, verbs|
      perm_name =  "Read #{key.to_s.capitalize}"
      unless Permission.where(:role_id => role, :name => perm_name).count > 0
        Permission.create!(:role => role,
                     :resource_type => ResourceType.find_or_create_by_name(key),
                     :all_tags => true,
                     :verbs => verbs.collect{|verb| Verb.find_or_create_by_verb(verb)},
                     :name => perm_name,
                     :organization=> organization,
                     :description => "Read #{key.to_s.capitalize} permission")
      end
    end

    role

  end

  # returns the candlepin role (for RHSM)
  def self.candlepin_role
    Role.find_by_name('candlepin_role')
  end


  #permissions
  scope :readable, lambda {where("0 = 1")  unless User.allowed_all_tags?(READ_PERM_VERBS, :roles)}
  def self.creatable?
    User.allowed_to?([:create], :roles, nil)
  end

  def self.editable?
   User.allowed_to?([:update, :create], :roles, nil)
  end

  def self.deletable?
    User.allowed_to?([:delete, :create],:roles, nil)
  end

  def self.any_readable?
    User.allowed_to?(READ_PERM_VERBS, :roles, nil)
  end

  def self.readable?
    Role.any_readable?
  end

  def summary
    perms = permissions.collect{|perm| perm.to_abbrev_text}.join("\n")
    "Role: #{name}\nPermissions:\n#{perms}"
  end

  def self.list_verbs global = false
    {
    :create => _("Administer Roles"),
    :read => _("Read Roles"),
    :update => _("Modify Roles"),
    :delete => _("Delete Roles"),
    }.with_indifferent_access
  end

  def self.read_verbs
    [:read]
  end

  def self.no_tag_verbs
    [:create]
  end

  private
  READ_PERM_VERBS = [:read,:update, :create,:delete]

  def extended_index_attrs
    {:name_sort=>name.downcase,
     :permissions=>self.permissions.collect{|p| p.name},
    }
  end


end
