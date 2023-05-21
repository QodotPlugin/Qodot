using System;
using System.Collections.Generic;
using Godot;

namespace Qodot
{
	public enum EntitySpawnType
	{
		WORLDSPAWN = 0,
		MERGE_WORLDSPAWN = 1,
		ENTITY = 2,
		GROUP = 3
	}

	public struct FacePoints
	{
		public Vector3 v0, v1, v2;
	}

	public struct ValveTextureAxis
	{
		public Vector3 axis;
		public float offset;
	}

	public struct ValveUV
	{
		public ValveTextureAxis U, V;
	}

	public struct FaceUVExtra
	{
		public float rot, scaleX, scaleY;
	}

	public struct Face
	{
		public FacePoints planePoints;
		public Vector3 planeNormal;
		public float planeDist;
		public int textureIdx;
		public bool isValveUV;
		public Vector2 uvStandard;
		public ValveUV uvValve;
		public FaceUVExtra uvExtra;
	}

	public struct Brush
	{
		public List<Face> faces = new List<Face>();
		public Vector3 center;

		public Brush()
		{
			center = Vector3.Zero;
		}
	}

	public struct Entity
	{
		public Godot.Collections.Dictionary<string, string> properties;
		public List<Brush> brushes;
		public Vector3 center;
		public EntitySpawnType spawnType;

		public Entity()
		{
			properties = new Godot.Collections.Dictionary<string, string>();
			brushes = new List<Brush>();
			center = Vector3.Zero;
			spawnType = EntitySpawnType.ENTITY;
		}
	}

	public struct FaceVertex
	{
		public Vector3 vertex;
		public Vector3 normal;
		public Vector2 uv;
		public Vector4 tangent;
	}

	public class FaceGeometry
	{
		public List<FaceVertex> vertices = new List<FaceVertex>();
		public List<int> indices = new List<int>();
	}

	public class BrushGeometry
	{
		public List<FaceGeometry> faces = new List<FaceGeometry>();
	}

	public class EntityGeometry
	{
		public List<BrushGeometry> brushes = new List<BrushGeometry>();
	}

	public struct TextureData
	{
		public string name;
		public int width, height;

		public TextureData(string name, int width = 0, int height = 0)
		{
			this.name = name;
			this.width = width;
			this.height = height;
		}
	}

	public struct WorldspawnLayer
	{
		public int textureIdx;
		public bool buildVisuals;

		public WorldspawnLayer(int textureIdx, bool buildVisuals)
		{
			this.textureIdx = textureIdx;
			this.buildVisuals = buildVisuals;
		}
	}
}