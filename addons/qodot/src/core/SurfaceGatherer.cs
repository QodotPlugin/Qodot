using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using Godot;

namespace Qodot
{
	public class SurfaceGatherer
	{
		public List<FaceGeometry> outSurfaces = new List<FaceGeometry>();
		public MapData mapData;

		public SurfaceSplitType splitType = SurfaceSplitType.NONE;
		public int entityFilterIdx = -1;
		public int textureFilterIdx = -1;
		public int brushFilterTextureIdx;
		public int faceFilterTextureIdx;
		public bool filterWorldspawnLayers;
		
		public SurfaceGatherer(MapData mapData)
		{
			this.mapData = mapData;
		}

		public void Run()
		{
			outSurfaces.Clear();

			int index_offset = 0;

			int surfIdx = -1;

			if (splitType == SurfaceSplitType.NONE) AddSurface();

			Span<Entity> entitySpan = mapData.GetEntitiesSpan();
			for (int e = 0; e < entitySpan.Length; e++)
			{
				if (FilterEntity(e)) continue;

				if (splitType == SurfaceSplitType.ENTITY)
				{
					if (entitySpan[e].spawnType == EntitySpawnType.MERGE_WORLDSPAWN)
					{
						AddSurface();
						surfIdx = 0;
						index_offset = outSurfaces[surfIdx].vertices.Count; 
					}
					else
					{
						surfIdx = AddSurface();
						index_offset = outSurfaces[surfIdx].vertices.Count; 
					}
				}
			
				Span<BrushGeometry> brushGeoSpan = mapData.GetBrushGeoSpan(e);
				for (int b = 0; b < brushGeoSpan.Length; b++)
				{

					if (splitType == SurfaceSplitType.BRUSH)
					{
						surfIdx = AddSurface();
						index_offset = 0;
					}

					Span<FaceGeometry> faceGeoSpan = mapData.GetFaceGeoSpan(e, b);
					for (int f = 0; f < faceGeoSpan.Length; f++)
					{
						if (FilterFace(e, b, f)) continue;

						ref FaceGeometry faceGeo = ref faceGeoSpan[f];

						Span<FaceVertex> vertexSpan = CollectionsMarshal.AsSpan(faceGeo.vertices);
						for (int v = 0; v < vertexSpan.Length; v++)
						{
							if (entitySpan[e].spawnType == EntitySpawnType.ENTITY ||
								entitySpan[e].spawnType == EntitySpawnType.GROUP)
							{
								vertexSpan[v].vertex -= entitySpan[e].center;
							}
							if(FilterBrush(e, b)) continue;
							outSurfaces[surfIdx].vertices.Add(vertexSpan[v]);
						}
						
						for (int i = 0; i < (faceGeo.vertices.Count - 2) * 3; i++)
						{
							outSurfaces[surfIdx].indices.Add(faceGeo.indices[i] + index_offset);
						}

						index_offset += faceGeo.vertices.Count;
					}
				}
			}
		}

		public void SetTextureFilter(string textureName)
		{
			textureFilterIdx = mapData.FindTexture(textureName);
		}

		public void SetBrushFilterTexture(string textureName)
		{
			brushFilterTextureIdx = mapData.FindTexture(textureName);
		}

		public void SetFaceFilterTexture(string textureName)
		{
			faceFilterTextureIdx = mapData.FindTexture(textureName);
		}

		private bool FilterEntity(int entityIdx)
		{
			return entityFilterIdx != -1 && entityIdx != entityFilterIdx;
		}

		private bool FilterBrush(int entityIdx, int brushIdx)
		{
			Span<Face> faceSpan = mapData.GetFacesSpan(entityIdx, brushIdx);

			if (brushFilterTextureIdx != -1)
			{
				bool fullyTextured = true;
				for (int f = 0; f < faceSpan.Length; f++)
				{
					if (faceSpan[f].textureIdx != brushFilterTextureIdx)
					{
						fullyTextured = false;
						break;
					}
				}

				if (fullyTextured) return true;
			}

			for (int f = 0; f < faceSpan.Length; f++)
			{
				for (int l = 0; l < mapData.worldspawnLayers.Count; l++)
				{
					if (faceSpan[f].textureIdx == mapData.worldspawnLayers[l].textureIdx) return filterWorldspawnLayers;
				}
			}
			
			return false;
		}

		private bool FilterFace(int entityIdx, int brushIdx, int faceIdx)
		{
			Span<Face> faceSpan = mapData.GetFacesSpan(entityIdx, brushIdx);
			Span<FaceGeometry> faceGeoSpan = mapData.GetFaceGeoSpan(entityIdx, brushIdx);
			if (faceGeoSpan[faceIdx].vertices.Count < 3) return true;
			
			// Omit faces textured with skip.
			if (faceFilterTextureIdx != -1 && faceSpan[faceIdx].textureIdx == faceFilterTextureIdx) return true;
			
			// Omit filtered texture indices.
			if (textureFilterIdx != -1 && faceSpan[faceIdx].textureIdx != textureFilterIdx) return true;
			
			return false;
		}

		private int AddSurface()
		{
			outSurfaces.Add(new FaceGeometry());
			return outSurfaces.Count - 1;
		}

		public void ResetParams()
		{
			splitType = SurfaceSplitType.NONE;
			entityFilterIdx = -1;
			textureFilterIdx = -1;
			brushFilterTextureIdx = -1;
			faceFilterTextureIdx = -1;
			filterWorldspawnLayers = true;
		}
	}
	
	public enum SurfaceSplitType
	{
		NONE,
		ENTITY,
		BRUSH
	}
}
