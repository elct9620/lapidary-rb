# frozen_string_literal: true

module TripletHelpers
  def build_node(type:, name:, properties: {})
    Analysis::Entities::Node.new(type: type, name: name, properties: properties)
  end

  def build_triplet(subject:, relationship:, object:, evidence: nil)
    Analysis::Entities::Triplet.new(subject: subject, relationship: relationship, object: object, evidence: evidence)
  end

  def maintainer_triplet(name: 'matz', module_name: 'String', evidence: nil)
    build_triplet(
      subject: build_node(type: Analysis::Entities::NodeType::RUBYIST, name: name, properties: { role: 'maintainer' }),
      relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
      object: build_node(type: Analysis::Entities::NodeType::CORE_MODULE, name: module_name),
      evidence: evidence
    )
  end

  def contributor_triplet(name: 'contributor', module_name: 'String')
    build_triplet(
      subject: build_node(type: Analysis::Entities::NodeType::RUBYIST, name: name, properties: { role: 'contributor' }),
      relationship: Analysis::Entities::RelationshipType::MAINTENANCE,
      object: build_node(type: Analysis::Entities::NodeType::CORE_MODULE, name: module_name)
    )
  end

  def invalid_triplet(object_name: 'String')
    build_triplet(
      subject: build_node(type: Analysis::Entities::NodeType::CORE_MODULE, name: object_name),
      relationship: Analysis::Entities::RelationshipType::CONTRIBUTE,
      object: build_node(type: Analysis::Entities::NodeType::RUBYIST, name: 'someone')
    )
  end
end

RSpec.configure do |config|
  config.include TripletHelpers
end
