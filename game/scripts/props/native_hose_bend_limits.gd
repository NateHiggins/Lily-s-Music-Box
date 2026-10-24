extends RefCounted
## Lower bend-radius bound from the actual imported outer section. A flattened
## ribbon may bend about its thin axis; a round fitting neck may not collapse
## to that same radius. Direction-dependent/self-contact protection is separate.
static func for_contact(contact: RefCounted) -> PackedFloat64Array:
 var result:=PackedFloat64Array()
 if contact==null or not contact.ready or contact.sections.size()<3:return result
 for section: Dictionary in contact.sections:
  var radius:=INF
  if section.outer.size()!=32:return PackedFloat64Array()
  for vertex: Vector3 in section.outer:
   if not vertex.is_finite():return PackedFloat64Array()
   radius=minf(radius,vertex.length())
  if not is_finite(radius) or radius<=0.:return PackedFloat64Array()
  result.append(maxf(.003,radius*1.02+.0001))
 return result
