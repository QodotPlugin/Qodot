using Godot;
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using Godot.Collections;
using Godot.NativeInterop;

#if TOOLS
[Tool]
public partial class QuakeWadImportPlugin : EditorImportPlugin
{
	private enum WadEntryType {
		Palette = 0x40,
		SBarPic = 0x42,
		MipsTexture = 0x44,
		ConsolePic = 0x45
	}

	private struct WadEntry
	{
		public uint offset;
		public uint inWadSize;
		public uint size;
		public byte type;
		public byte compression;
		public ushort unknown;
		public string nameStr;
	}

	private struct TextureData
	{
		public string name;
		public uint width;
		public uint height;
		public byte[] pixelData;

		public TextureData(string name, uint width, uint height, byte[] pixelData)
		{
			this.name = name;
			this.width = width;
			this.height = height;
			this.pixelData = pixelData;
		}
	}

	private const int TEXTURE_NAME_LENGTH = 16;
	private const int MAX_MIP_LEVELS = 4;

	public override string _GetImporterName()
	{
		return "qodot.wad";
	}

	public override string _GetVisibleName()
	{
		return "Quake Texture2D WAD";
	}

	public override string _GetResourceType()
	{
		return "Resource";
	}

	public override string[] _GetRecognizedExtensions()
	{
		return new []{ "wad" };
	}
	
	public override string _GetSaveExtension()
	{
		return "tres";
	}

	public override bool _GetOptionVisibility(
		string path,
		StringName optionName,
		Dictionary options)
	{
		return true;
	}
	
	public override Array<Dictionary> _GetImportOptions(string path, int presetIndex)
	{
		Dictionary paletteDict = new Dictionary();
		paletteDict.Add("name", "palette_file");
		paletteDict.Add("default_value", "res://addons/qodot/palette.lmp");
		paletteDict.Add("property_hint", (int)PropertyHint.File);
		paletteDict.Add("hint_string", "*.lmp");
		
		Dictionary getMipsDict = new Dictionary();
		getMipsDict.Add("name", "generate_mipmaps");
		getMipsDict.Add("default_value", true);
		getMipsDict.Add("property_hint", (int)PropertyHint.None);

		return new Array<Dictionary>(new []{ paletteDict, getMipsDict });
	}

	public override int _GetPresetCount()
	{
		return 0;
	}

	public override int _GetImportOrder()
	{
		return 0;
	}

	public override float _GetPriority()
	{
		return 1.0f;
	}
	
	public override Error _Import(
		string sourceFile,
		string savePath,
		Dictionary options,
		Array<string> platformVariants,
		Array<string> genFiles)
	{
		var QuakeWadFile = GD.Load<GDScript>("res://addons/qodot/src/resources/quake_wad_file.gd");

		string savePathStr = savePath + "." + _GetSaveExtension();

		var file = FileAccess.Open(sourceFile, FileAccess.ModeFlags.Read);
		if (file == null)
		{
			Error err = FileAccess.GetOpenError();
			GD.PrintErr("Error opening WAD file: " + err.ToString());
			return err;
		}

		string palettePath = options["palette_file"].AsString();
		var paletteFile = GD.Load<Resource>(palettePath);
		if (paletteFile == null)
		{
			GD.PrintErr("Invalid palette file");
			return Error.CantAcquireResource;
		}

		var magicStr = file.GetBuffer(4).GetStringFromAscii();
		if (magicStr != "WAD2")
		{
			GD.PrintErr("Invalid WAD magic");
			return Error.InvalidData;
		}

		uint numEntries = file.Get32();
		uint dirOffset = file.Get32();
		
		file.Seek(0);
		file.Seek(dirOffset);

		var entries = new List<WadEntry>();
		for (int i = 0; i < numEntries; i++)
		{
			WadEntry entry = new WadEntry();
			entry.offset = file.Get32();
			entry.inWadSize = file.Get32();
			entry.size = file.Get32();
			entry.type = file.Get8();
			entry.compression = file.Get8();
			entry.unknown = file.Get16();
			entry.nameStr = file.GetBuffer(TEXTURE_NAME_LENGTH).GetStringFromAscii();

			if (entry.type == (byte)WadEntryType.MipsTexture)
			{
				entries.Add(entry);
			}
		}

		var textureDataArray = new TextureData[entries.Count];
		for (int i = 0; i < entries.Count; i++)
		{
			file.Seek(0);
			file.Seek(entries[i].offset);

			string nameStr = file.GetBuffer(TEXTURE_NAME_LENGTH).GetStringFromAscii();
			uint width = file.Get32();
			uint height = file.Get32();

			uint[] mipOffsets = new uint[MAX_MIP_LEVELS];
			for (int j = 0; j < MAX_MIP_LEVELS; j++)
			{
				mipOffsets[j] = file.Get32();
			}

			textureDataArray[i] = new TextureData(nameStr, width, height, file.GetBuffer(width * height));
		}

		var textures = new Godot.Collections.Dictionary<string, ImageTexture>();
		var colors = paletteFile.Get("colors").AsColorArray();
		Span<TextureData> textureDataSpan = textureDataArray;
		for (int i = 0; i < textureDataSpan.Length; i++)
		{
			ref TextureData tex = ref textureDataSpan[i];

			var pixelsRgb = new byte[tex.pixelData.Length * 3];
			for (int j = 0; j < tex.pixelData.Length; j++)
			{
				var rgbColor = colors[tex.pixelData[j]];
				pixelsRgb[(j * 3)    ] = (byte)rgbColor.R8;
				pixelsRgb[(j * 3) + 1] = (byte)rgbColor.G8;
				pixelsRgb[(j * 3) + 2] = (byte)rgbColor.B8;
			}

			var textureImage = Image.CreateFromData((int)tex.width, (int)tex.height, false, Image.Format.Rgb8, pixelsRgb);
			if (options["generate_mipmaps"].AsBool())
			{
				textureImage.GenerateMipmaps();
			}
			var texture = ImageTexture.CreateFromImage(textureImage);

			textures[tex.name] = texture;
		}

		var wadResource = QuakeWadFile.New(textures).AsGodotObject() as Resource;
		return ResourceSaver.Save(wadResource, savePathStr);
	}
}
#endif //TOOLS
