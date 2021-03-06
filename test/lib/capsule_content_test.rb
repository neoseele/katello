require 'katello_test_helper'

module Katello
  class CapsuleContentTest < ActiveSupport::TestCase
    include Support::CapsuleSupport

    let(:organization) { taxonomies(:empty_organization) }
    let(:environment) { katello_environments(:organization1_library) }

    specify "listing available environments to add" do
      capsule_content.available_lifecycle_environments(organization.id).wont_include(environment)

      capsule_content.add_lifecycle_environment(environment)
      capsule_content.available_lifecycle_environments.wont_include(environment)
    end

    specify "listing environments in the capsule" do
      capsule_content.add_lifecycle_environment(environment)
      capsule_content.lifecycle_environments.must_include(environment)
      capsule_content.lifecycle_environments(organization.id).wont_include(environment)
    end

    specify "listing capsule content in environment" do
      pulp_node_feature = Feature.create(:name => SmartProxy::PULP_NODE_FEATURE)
      pulp_default_feature = Feature.create(:name => SmartProxy::PULP_FEATURE)

      with_pulp_node = smart_proxies(:four).tap do |proxy|
        proxy.features << pulp_node_feature
      end
      with_pulp = smart_proxies(:three).tap do |proxy|
        proxy.features << pulp_default_feature
      end
      pulp_node_capsule_content = Katello::CapsuleContent.new(with_pulp_node)
      pulp_node_capsule_content.add_lifecycle_environment(environment)

      pulp_capsule_content = Katello::CapsuleContent.new(with_pulp)
      pulp_capsule_content.add_lifecycle_environment(environment)

      refute_includes CapsuleContent.with_environment(environment, false).map(&:capsule), with_pulp
      refute_includes CapsuleContent.with_environment(environment).map(&:capsule), with_pulp
      assert_includes CapsuleContent.with_environment(environment).map(&:capsule), with_pulp_node

      assert_includes CapsuleContent.with_environment(environment, true).map(&:capsule), with_pulp
      assert_includes CapsuleContent.with_environment(environment, true).map(&:capsule), with_pulp_node
    end
  end
end
