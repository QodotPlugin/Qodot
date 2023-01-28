using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using Godot;
using Godot.Collections;
using Godot.NativeInterop;
using Array = Godot.Collections.Array;
using Object = Godot.GodotObject;

namespace Qodot
{
	public partial class Qodot : RefCounted
	{
		public MapData mapData;
		public MapParser mapParser;
		public GeoGenerator geoGenerator;
		public SurfaceGatherer surfaceGatherer;

		public Qodot()
		{
			Reset();
		}

		public void Reset()
		{
			mapData = new MapData();
			mapParser = new MapParser(mapData);
			geoGenerator = new GeoGenerator(mapData);
			surfaceGatherer = new SurfaceGatherer(mapData);
		}

		public void LoadMap(string filename)
		{
			mapParser.Load(filename);
		}

		public Array<string> GetTextureList()
		{
			int texCount = mapData.textures.Count;
			Array<string> outTex = new Array<string>();
			outTex.Resize(texCount);
			for (int i = 0; i < texCount; i++)
			{
				outTex[i] = mapData.textures[i].name;
			}
			return outTex; 
		}

		public void SetEntityDefinitions(Dictionary entityDefs)
		{
			Variant[] keys = entityDefs.Keys.ToArray();
			Variant[] vals = entityDefs.Values.ToArray();
			
			for (int i = 0; i < entityDefs.Count; i++)
			{
				var valDict = vals[i].AsGodotDictionary<string, int>();
				string key = keys[i].AsString();
				int val = valDict.GetValueOrDefault("spawn_type", (int)EntitySpawnType.ENTITY);
				mapData.SetSpawnTypeByClassname(key, (EntitySpawnType)val);
			}
		}

		public void SetWorldspawnLayers(Array worldspawnLayers)
		{
			for (int i = 0; i < worldspawnLayers.Count; i++)
			{
				Object layer = worldspawnLayers[i].AsGodotObject();
				bool buildVisuals = layer.Get("build_visuals").AsBool();
				string texture = layer.Get("texture").AsString() ?? "NONE";
				mapData.worldspawnLayers.Add(new WorldspawnLayer(mapData.FindTexture(texture), buildVisuals));
			}
		}

		public void GenerateGeometry(Dictionary textureDict)
		{
			Variant[] keys = textureDict.Keys.ToArray();
			for (int i = 0; i < keys.Length; i++)
			{
				Vector2 val = textureDict[keys[i]].AsVector2();
				mapData.SetTextureSize(keys[i].AsString(), (int)val.X, (int)val.Y);
			}
			geoGenerator.Run();
		}

		public Array<Dictionary> GetWorldspawnLayerDicts()
		{
			Array<Dictionary> worldspawnLayerDicts = new Array<Dictionary>();
			if (mapData.entities.Count <= 0) return worldspawnLayerDicts;

			ref Entity worldspawnEnt = ref mapData.GetEntitiesSpan()[0];

			for (int l = 0; l < mapData.worldspawnLayers.Count; l++)
			{
				Dictionary layerDict = new Dictionary();
				WorldspawnLayer layer = mapData.worldspawnLayers[l];
				TextureData texData = mapData.textures[layer.textureIdx];

				layerDict["texture"] = texData.name;

				Array<int> brushIndices = new Array<int>();
				Span<Brush> brushSpan = CollectionsMarshal.AsSpan(worldspawnEnt.brushes);
				for (int b = 0; b < brushSpan.Length; b++)
				{
					bool isLayerBrush = false;
					Span<Face> faceSpan = CollectionsMarshal.AsSpan(brushSpan[b].faces);
					for (int f = 0; f < faceSpan.Length; f++)
					{
						if (faceSpan[f].textureIdx == layer.textureIdx)
						{
							isLayerBrush = true;
							break;
						}
					}
					
					if (isLayerBrush) brushIndices.Add(b);
				}

				layerDict["brush_indices"] = brushIndices;
				worldspawnLayerDicts.Add(layerDict);
			}

			return worldspawnLayerDicts;
		}

		public Array<Dictionary> GetEntityDicts()
		{
			Array<Dictionary> entDicts = new Array<Dictionary>();

			Span<Entity> entitySpan = mapData.GetEntitiesSpan();
			for (int e = 0; e < entitySpan.Length; e++)
			{   
				Dictionary dict = new Dictionary();
				dict["brush_count"] = entitySpan[e].brushes.Count;
				
				Array<int> brushIndices = new Array<int>();
				Span<Brush> brushSpan = mapData.GetBrushesSpan(e);
				for (int b = 0; b < brushSpan.Length; b++)
				{
					bool isWslBrush = false;
					Span<Face> faceSpan = mapData.GetFacesSpan(e, b);
					for (int f = 0; f < faceSpan.Length; f++)
					{
						if (mapData.FindWorldspawnLayer(faceSpan[f].textureIdx) != -1)
						{
							isWslBrush = true;
							break;
						}
					}
					if(!isWslBrush) brushIndices.Add(b);
				}

				dict["brush_indices"] = brushIndices;
				dict["center"] = new Vector3(entitySpan[e].center.Y, entitySpan[e].center.Z, entitySpan[e].center.X);
				dict["properties"] = entitySpan[e].properties;
				
				entDicts.Add(dict);
			}

			return entDicts;
		}

		public void GatherTextureSurfaces(string texName, string brushFilterTex, string faceFilterTex)
		{
			GatherTextureSurfacesInternal(texName, brushFilterTex, faceFilterTex, true);
		}

		public void GatherWorldspawnLayerSurfaces(string texName, string brushFilterTex, string faceFilterTex)
		{
			GatherTextureSurfacesInternal(texName, brushFilterTex, faceFilterTex, false);
		}

		private void GatherTextureSurfacesInternal(string texName, string brushFilterTex, string faceFilterTex,
			bool filterLayers)
		{
			surfaceGatherer.ResetParams();
			surfaceGatherer.splitType = SurfaceSplitType.ENTITY;
			surfaceGatherer.SetTextureFilter(texName);
			surfaceGatherer.SetBrushFilterTexture(brushFilterTex);
			surfaceGatherer.SetFaceFilterTexture(faceFilterTex);
			surfaceGatherer.filterWorldspawnLayers = filterLayers;
			
			surfaceGatherer.Run();
		}

		public void GatherEntityConvexCollisionSurfaces(int entityIdx)
		{
			GatherConvexCollisionSurfaces(entityIdx, true);
		}
		
		public void GatherEntityConcaveCollisionSurfaces(int entityIdx)
		{
			GatherConcaveCollisionSurfaces(entityIdx, true);
		}

		public void GatherWorldspawnLayerCollisionSurfaces(int entityIdx)
		{
			GatherConvexCollisionSurfaces(entityIdx, false);
		}

		private void GatherConvexCollisionSurfaces(int entityIdx, bool filterLayers)
		{
			surfaceGatherer.ResetParams();
			surfaceGatherer.splitType = SurfaceSplitType.BRUSH;
			surfaceGatherer.entityFilterIdx = entityIdx;
			surfaceGatherer.filterWorldspawnLayers = filterLayers;
			
			surfaceGatherer.Run();
		}
		
		private void GatherConcaveCollisionSurfaces(int entityIdx, bool filterLayers)
		{
			surfaceGatherer.ResetParams();
			surfaceGatherer.splitType = SurfaceSplitType.NONE;
			surfaceGatherer.entityFilterIdx = entityIdx;
			surfaceGatherer.filterWorldspawnLayers = filterLayers;
			
			surfaceGatherer.Run();
		}

		public Array FetchSurfaces(float inverseScaleFactor)
		{
			Span<FaceGeometry> surfsSpan = CollectionsMarshal.AsSpan(surfaceGatherer.outSurfaces);
			Array surfsArray = new Array();

			for (int s = 0; s < surfsSpan.Length; s++)
			{
				if (surfsSpan[s] == null || surfsSpan[s].vertices.Count == 0)
				{
					surfsArray.Add(new Variant());
					continue;
				}

				Span<FaceVertex> vertexSpan = CollectionsMarshal.AsSpan(surfsSpan[s].vertices);
				Span<int> indexSpan = CollectionsMarshal.AsSpan(surfsSpan[s].indices);
				
				Vector3[] vertices = new Vector3[vertexSpan.Length];
				Vector3[] normals = new Vector3[vertexSpan.Length];
				float[] tangents = new float[vertexSpan.Length * 4];
				Vector2[] uvs = new Vector2[vertexSpan.Length];
				
				for (int i = 0; i < vertexSpan.Length; i++)
				{
					ref FaceVertex v = ref vertexSpan[i];
					vertices[i] = new Vector3(v.vertex.Y, v.vertex.Z, v.vertex.X) / inverseScaleFactor;
					normals[i] = new Vector3(v.normal.Y, v.normal.Z, v.normal.X);
					tangents[(i * 4)    ] = v.tangent.Y;
					tangents[(i * 4) + 1] = v.tangent.Z;
					tangents[(i * 4) + 2] = v.tangent.X;
					tangents[(i * 4) + 3] = v.tangent.W;
					uvs[i] = new Vector2(v.uv.X, v.uv.Y);
				}

				int[] indices = new int[surfsSpan[s].indices.Count];
				for (int i = 0; i < surfsSpan[s].indices.Count; i++)
				{
					indices[i] = surfsSpan[s].indices[i];
				}

				Array brushArray = new Array();
				brushArray.Resize((int)Mesh.ArrayType.Max);
				brushArray[(int)Mesh.ArrayType.Vertex] = vertices;
				brushArray[(int)Mesh.ArrayType.Normal] = normals;
				brushArray[(int)Mesh.ArrayType.Tangent] = tangents;
				brushArray[(int)Mesh.ArrayType.TexUV] = uvs;
				brushArray[(int)Mesh.ArrayType.Index] = indices;
				
				surfsArray.Add(brushArray);
			}

			return surfsArray;
		}
	}
}
