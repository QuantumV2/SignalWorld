extends Node2D

@onready var logic_arrows = $LogicArrows

var text = ""

class Chunk:
	var chunks = {}
	func qset(s,a):
		if s in chunks:
			chunks[s].append(a)
		else:
			chunks[s] = [a]
	func the16(vector):
		var vectorx = vector.x % 16
		var vectory = vector.y
		var vectorz = vectory * 16 + vectorx
		return vectorz
	func thenormal(aint):
		var normalx = aint % 16
		var normaly = aint / 16
		var normal = Vector2i(normalx,normaly)
		return normal

class Packed:
	var bytarr = PackedByteArray()
	
	func push8(val):
		bytarr.append(val%256)
	func push16(val):
		bytarr.append(val%256)
		bytarr.append(val/256)
	func pop8() -> int:
		var val = bytarr.slice(0, 1)
		bytarr = bytarr.slice(1, bytarr.size())
		return val[0]
	func pop16():
		var val = bytarr.slice(0, 2)
		bytarr = bytarr.slice(2, bytarr.size())
		if val.size() == 0:
			return null
		return val[0] + val[1] * 256


func set_array(tilemap):
	var tiles = tilemap.get_used_cells(0)
	var chunks = Chunk.new()
	for i in tiles:
		chunks.qset(i/16,chunks.the16(i%16))
	return chunks.chunks

var version = 0

func export(chunks):
	var bytarr = Packed.new()
	bytarr.push16(0)
	bytarr.push16(chunks.size())
	for i in chunks:
		var types = Chunk.new()
		for ii in chunks[i]:
			var arrowpos = Chunk.new().thenormal(ii)+(Vector2i(i)*16)
			var id = logic_arrows.get_id("logic_arrows",arrowpos)
			types.qset(id,ii)
		var chunkx = i.x
		var chunky = i.y
		bytarr.push16(chunkx)
		bytarr.push16(chunky)
		bytarr.push8(types.chunks.size()-1)
		for ii in types.chunks:
			bytarr.push8(ii)
			bytarr.push8(0)
			var types_count_index = bytarr.bytarr.size()-1
			var types_count = 0
			for iii in types.chunks[ii]:
				var arrowpos = Chunk.new().thenormal(iii)+(Vector2i(i)*16)
				#var id = logic_arrows.get_id("logic_arrows",arrowpos) UNUSED_VAR
				var dir = logic_arrows.get_rotate(arrowpos)
				bytarr.push8(iii)
				bytarr.push8(dir)
				types_count += 1
			bytarr.bytarr[types_count_index] = types_count-1
	return Marshalls.raw_to_base64(bytarr.bytarr)

func import(tilemap,string):
	var bytarr = Packed.new()
	#var version = 0 UNUSED_VAR
	bytarr.bytarr = Marshalls.base64_to_raw(string)
	version = bytarr.pop16()
	if version == null:
		return
	var chunks_count = bytarr.pop16()
	for i in range(chunks_count):
			var chunk_x = bytarr.pop16()
			var chunk_y = bytarr.pop16()
			var arrow_types = bytarr.pop8()+1
			for ii in range(arrow_types):
				var type = bytarr.pop8()
				var type_count = bytarr.pop8()+1
				for iii in range(type_count):
					var aposition = bytarr.pop8()
					var ax = aposition & 0x0F
					var ay = (aposition & 0xF0) >> 4
					var adirection = bytarr.pop8()
					tilemap.set_arrows(Vector2i(chunk_x*16 + ax,chunk_y*16 + ay),type,adirection)
