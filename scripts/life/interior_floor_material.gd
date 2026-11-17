extends RefCounted
## Board seams share the floor surface and use mip filtering instead of subpixel geometry.
static func make(base:StandardMaterial3D) -> StandardMaterial3D:
 var material:StandardMaterial3D=base.duplicate()
 var image:=Image.create(256,16,false,Image.FORMAT_RGBA8)
 image.fill(Color.WHITE)
 for x in range(6):
  for y in range(16):image.set_pixel(x,y,Color(.82,.78,.72))
 image.generate_mipmaps()
 material.albedo_texture=ImageTexture.create_from_image(image)
 material.uv1_scale=Vector3(16,1,1)
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return material
