xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "csv";
declare option output:csv "header=yes, separator=tab";
(: in basex, the options above will convert the output to TSV format and you can save to a .tsv file
:)

(:
a caveat: as downloaded, the xml files did not quite validate as TEI. the culprit was @hand attributes in the wrong place, mostly in teiHeader; the information was provided elsewhere so I simply deleted these. 
:)

for $docs in collection('/path/to/letters/BC_all_xml')

let $doc := $docs/tei:TEI
let $doc_id:= $doc/@xml:id

let $header:= $doc/tei:teiHeader

let $title:= $header//tei:titleStmt/tei:title
let $pub_id:= $header//tei:publicationStmt//tei:idno[@type="docID"]
(:<idno type="docID">:)

let $ms_id:= $header//tei:msIdentifier//tei:idno[@type="shelfmark"]

let $profile:= $header//tei:profileDesc

let $creation:= $header//tei:creation
let $date_day:= $creation//tei:date[@type="day"]/@when
let $date_month:= $creation//tei:date[@type="month"]/@when
let $date_year:= $creation//tei:date[@type="year"]/@when

let $place := $creation//tei:placeName
let $place_type:= $place//@type
let $settlement:= $creation//tei:settlement
let $region:= $creation//tei:region
let $country:= $creation//tei:country

(: does not seem to be more than 1 <person> sender or recipient per letter:)
let $sender:= $profile//tei:person[@role="sender"] 
let $sender_id:= $sender/@corresp
(: but there can be more than one persName per person. only 1 of these in sender; 0 in recipient. doesn't *actually* seem to be more than 1 sender anywhere. :-/ :)
let $sender_name := $sender//tei:persName

let $recipient:= $profile//tei:person[@role="recipient"]
let $recipient_id:= $recipient/@corresp
let $recipient_name:= $recipient//tei:persName

return 

<csv>
<record>
<docid>{data($doc_id)}</docid>
<pubid>{data($pub_id)}</pubid>
<msref>{data($ms_id)}</msref>
<title>{ normalize-space(data($title)) }</title>
<date_day>{data($date_day)}</date_day>
<date_month>{data($date_month)}</date_month>
<date_year>{data($date_year)}</date_year>
<place>{normalize-space(data($place))}</place>
<place_type>{data($place_type)}</place_type>
<place_settlement>{normalize-space(data($settlement) )}</place_settlement>
<place_region>{ normalize-space(data($region))}</place_region>
<place_country>{normalize-space(data($country))}</place_country>
<sender>{ normalize-space(data($sender) ) }</sender>
<sender_id>{data($sender_id)}</sender_id>
<recipient>{normalize-space(data($recipient_name))}</recipient>
<recipient_id>{data($recipient_id)}</recipient_id>
</record>
</csv>
