require 'net/http'
require 'nokogiri'

# fetch metadata, find entityID matches
@doc = Nokogiri::XML(Net::HTTP.get(URI('http://md.incommon.org/InCommon/InCommon-metadata-idp-only.xml')))
@doc.remove_namespaces! # until/unless we figure out how to do this right

def get_EntityDescriptors(q)
  # search for entities w/ matching entityIDs, limit search to SSO providers
  @doc.xpath("//EntityDescriptor[contains(@entityID,'#{q}')][.//SingleSignOnService][@entityID]")
end

def get_EntityDescriptor(q)
  eds = get_EntityDescriptors(q)
  if (eds.size != 1)
    return nil
  end
  eds[0]
end

def get_entityIDs(q)
  get_EntityDescriptors(q).map{ |ed| ed.get_attribute("entityID") }
end

def get_entity_info(q)
  ret = nil
  entities = get_EntityDescriptors(q)

  if (entities.size == 1)
    entity = entities[0]
    eid = entity.get_attribute("entityID")

    support = entity.xpath("ContactPerson[@contactType = 'support'][./EmailAddress]").map{ |cp| cp.xpath("./EmailAddress")[0].content }
    technical = entity.xpath("ContactPerson[@contactType = 'technical'][./EmailAddress]").map{ |cp| cp.xpath("./EmailAddress")[0].content }

    support.uniq!
    technical.uniq!
    ret = { support_contacts: support, technical_contacts: technical, entityID: eid }
  end

  ret
end

def mk_initiator(eid)
  location = nil  

  /\b(?<domain>[a-z\-]+)\.(edu|gov|com|org|net)/ =~ eid
  location = domain
  location ||= 'LOCATION_HERE'

  <<SessionInitiator
<SessionInitiator type="Chaining" Location="/#{location}"
    entityID="#{eid}" template="bindingTemplate.html">
    <SessionInitiator type="SAML2"/>
    <SessionInitiator type="Shib1"/>
</SessionInitiator>
SessionInitiator
end
