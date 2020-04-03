require 'net/http'
require 'nokogiri'


class ShibMetadata


  def initialize
    # fetch metadata, find entityID matches
    @doc = Nokogiri::XML(Net::HTTP.get(URI('http://md.incommon.org/InCommon/InCommon-metadata-idp-only.xml')))
    @doc.remove_namespaces! # until/unless we figure out how to do this right
  end

  def entity_descriptors(q)
    # search for entities w/ matching entityIDs, limit search to SSO providers
    @doc.xpath("//EntityDescriptor[contains(@entityID,'#{q}')][.//SingleSignOnService][@entityID]")
  end

  def entity_ids(q)
    entity_descriptors(q).map{ |ed| ed.get_attribute("entityID") }
  end

  def entity_info(q)
    ret = nil
    entities = entity_descriptors(q)

    if (entities.size == 1)
      entity = entities[0]
      eid = entity.get_attribute("entityID")

      support = entity.xpath("ContactPerson[@contactType = 'support'][./EmailAddress]").map{ |cp| cp.xpath("./EmailAddress")[0].content }
      technical = entity.xpath("ContactPerson[@contactType = 'technical'][./EmailAddress]").map{ |cp| cp.xpath("./EmailAddress")[0].content }

      support.uniq!
      technical.uniq!

      name = nil
      org = entity.xpath("./Organization/OrganizationName")[0]
      if org
        name = org.content
      end

      ret = { support_contacts: support, technical_contacts: technical, entityID: eid, name: name }
    end

    ret
  end

  # generate SessionInitiator for shibboleth2.xml
  # if location is skipped, attempts to guess location from entityID
  def initiator(eid,location=nil)
    unless(location)
      /\b(?<domain>[a-z\-]+)\.(edu|gov|com|org|net|ac\.uk)/ =~ eid
      location = domain
      location ||= 'LOCATION_HERE'
    end

    <<~SessionInitiator
      <SessionInitiator type="Chaining" Location="/#{location}"
	  entityID="#{eid}" template="bindingTemplate.html">
	  <SessionInitiator type="SAML2"/>
	  <SessionInitiator type="Shib1"/>
      </SessionInitiator>
    SessionInitiator
  end
end
