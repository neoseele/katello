# encoding: utf-8

require "katello_test_helper"

module Katello
  class Api::V2::HostCollectionsControllerTest < ActionController::TestCase
    def models
      @system = katello_systems(:simple_server)
      @system_two = katello_systems(:simple_server2)
      @host_collection = katello_host_collections(:simple_host_collection)
      @organization = get_organization

      HostCollection.stubs('any_readable?').with(@organization).returns(true)
      stub_find_organization(@organization)
    end

    def setup
      setup_controller_defaults_api
      login_user(User.find(users(:admin)))
      System.any_instance.stubs(:update_host_collections)

      models
    end

    def test_index
      results = JSON.parse(get(:index, :organization_id => @organization.id).body)

      assert_response :success
      assert_template 'api/v2/host_collections/index'

      assert_equal results.keys.sort, ['page', 'per_page', 'results', 'search', 'sort', 'subtotal', 'total']
      assert_equal results['results'].size, 3
      assert_block do
        ids = []
        results['results'].each do |r|
          ids << r['id']
        end
        ids.include? @host_collection.id
      end
    end

    def test_show
      results = JSON.parse(get(:show, :id => @host_collection.id).body)

      assert_equal results['name'], 'Simple Host Collection'

      assert_response :success
      assert_template 'api/v2/host_collections/show'
    end

    def test_create
      post :create, :organization_id => @organization,
                    :host_collection => {:name => 'Collection A', :description => 'Collection A, World Cup 2014',
                                         :system_ids => [@system.id]}

      assert_response :success

      results = JSON.parse(response.body)
      assert_equal results['name'], 'Collection A'
      assert_equal results['unlimited_content_hosts'], true
      assert_equal results['organization_id'], @organization.id
      assert_equal results['description'], 'Collection A, World Cup 2014'
      assert_equal results['system_ids'], [@system.id]

      assert_template 'api/v2/host_collections/create'
    end

    def test_validate_systems
      max_content_hosts = 1
      content_host_name = 'Collection A'
      post :create, :organization_id => @organization,
                    :host_collection => {:name => content_host_name, :description => 'Collection A, World Cup 2014',
                                         :max_content_hosts => max_content_hosts, :unlimited_content_hosts => false,
                                         :system_ids => [@system.id, @system_two.id]}

      results = JSON.parse(response.body)
      error_message = "You cannot have more than #{max_content_hosts} content host(s) associated with host collection #{content_host_name}."

      assert_response 422
      assert results["errors"]["base"].include?(error_message)
    end

    def test_max_content_host_validator
      put :update, :id => @host_collection.id, :organization_id => @organization.id,
                   :max_content_hosts => 2, :unlimited_content_hosts => false, :system_ids => [@system.id, @system_two.id]

      assert_response :success

      put :update, :id => @host_collection.id, :organization_id => @organization.id,
                   :max_content_hosts => 1

      results = JSON.parse(response.body)
      error_message = "may not be less than the number of content hosts associated with the host collection."

      assert_response 422
      assert results["errors"]["max_content_host"].include?(error_message)
    end

    def test_max_content_host_zero
      put :update, :id => @host_collection.id, :organization_id => @organization.id,
                   :max_content_hosts => 0, :unlimited_content_hosts => false

      results = JSON.parse(response.body)
      error_message = "must be a positive integer value."

      assert_response 422
      assert results["displayMessage"].include?(error_message)
    end

    def test_nil_max_content_hosts
      put :update, :id => @host_collection.id, :organization_id => @organization.id,
                   :unlimited_content_hosts => false

      results = JSON.parse(response.body)
      error_message = "must be given a value if this host collection is not unlimited."

      assert_response 422
      assert results["displayMessage"].include?(error_message)
    end

    def test_create_with_system_uuid
      post :create, :organization_id => @organization, :system_uuids => [@system.uuid],
        :host_collection => {:name => 'Collection A', :description => 'Collection A, World Cup 2014'}

      results = JSON.parse(response.body)
      assert_equal results['system_ids'], [@system.id]

      assert_response :success
      assert_template 'api/v2/host_collections/create'
    end
  end
end
