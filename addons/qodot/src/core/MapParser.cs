using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;

namespace Qodot
{
	public enum ParseScope
	{
		FILE,
		COMMENT,
		ENTITY,
		PROPERTY_VALUE,
		BRUSH,
		PLANE_0,
		PLANE_1,
		PLANE_2,
		TEXTURE,
		U,
		V,
		VALVE_U,
		VALVE_V,
		ROT,
		U_SCALE,
		V_SCALE
	};
	
	public class MapParser
	{
		public MapParser(MapData mapData)
		{
			this.mapData = mapData;
		}

		public MapData mapData;

		ParseScope scope;
		private string propKey = "";
		private string currentProperty = "";
		private bool valveUVs = false;
		
		private int componentIdx = 0;
		private Entity currentEntity;
		private Brush currentBrush;
		private Face currentFace;

		public bool Load(string filename)
		{
			currentEntity = new Entity();
			currentBrush = new Brush();
			currentFace = new Face();
			
			componentIdx = 0;
			valveUVs = false;

			scope = ParseScope.FILE;

			FileAccess file = FileAccess.Open(filename, FileAccess.ModeFlags.Read);
			if (file == null)
			{
				GD.PrintErr("Error: Failed to open map file (" + filename + ")");
				return false;
			}

			while (!file.EofReached())
			{
				string line = file.GetLine();
				if(line.StartsWith("//")) continue; // is a comment.

				List<string> tokens = CustomSplit(line);
				for (int i = 0; i < tokens.Count; i++)
				{
					ParseToken(tokens[i]);
				}
			}
			
			GD.Print("Map parsed: entities " + mapData.entities.Count.ToString());
			
			return true;
		}

		List<string> CustomSplit(string s)
		{
			List<string> parts = new List<string>();
			int start = 0;
			int i = 0;

			bool insideString = false;
			
			while (i < s.Length)
			{
				if (s[i] == '"') insideString = !insideString;
				if ((s[i] == '\t' || s[i] == ' ') && !insideString)
				{
					parts.Add(s.Substring(start, i - start));
					start = i + 1; 
				}  

				i++;
			}

			parts.Add(s.Substring(start, i - start));

			return parts;
		}

		private void ParseToken(string token)
		{
			switch (scope)
			{
				case ParseScope.FILE:
					if (token == "{")
					{
						scope = ParseScope.ENTITY;
					}

					break;
				case ParseScope.ENTITY:
					if (token.StartsWith('"'))
					{
						propKey = token.Substring(1);
						if (propKey.EndsWith('"'))
						{
							propKey = propKey.TrimEnd('"');
							scope = ParseScope.PROPERTY_VALUE;
						}
					}
					else if (token == "{")
					{
						scope = ParseScope.BRUSH;
					}
					else if (token == "}")
					{
						CommitEntity();
						scope = ParseScope.FILE;
					}

					break;
				case ParseScope.PROPERTY_VALUE:
					bool isFirst = token.StartsWith('"');
					bool isLast = token.EndsWith('"');
					
					if (isFirst && currentProperty != "") currentProperty = "";

					if (isFirst || isLast) currentProperty += token;
					else currentProperty += (" " + token + " ");

					if (isLast)
					{
						string prop = currentProperty.Substring(1, currentProperty.Length - 2);
						if (!currentEntity.properties.ContainsKey(propKey)) currentEntity.properties.Add(propKey, prop);
						else currentEntity.properties[propKey] = prop;
						scope = ParseScope.ENTITY;
					}

					break;
				case ParseScope.BRUSH:
					if (token == "(")
					{
						componentIdx = 0;
						scope = ParseScope.PLANE_0;
					}
					else if (token == "}")
					{
						CommitBrush();
						scope = ParseScope.ENTITY;
					}

					break;
				case ParseScope.PLANE_0:
					if (token == ")")
					{
						componentIdx = 0;
						scope = ParseScope.PLANE_1;
					}
					else
					{
						switch (componentIdx)
						{
							case 0:
								currentFace.planePoints.v0.X = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
							case 1:
								currentFace.planePoints.v0.Y = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
							case 2:
								currentFace.planePoints.v0.Z = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
						}
						
						componentIdx++;
					}

					break;
				case ParseScope.PLANE_1:
					if (token != "(")
					{
						if (token == ")")
						{
							componentIdx = 0;
							scope = ParseScope.PLANE_2;
						}
						else
						{
							switch (componentIdx)
							{
								case 0:
									currentFace.planePoints.v1.X = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 1:
									currentFace.planePoints.v1.Y = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 2:
									currentFace.planePoints.v1.Z = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
							}

							componentIdx++;
						}
					}
					
					break;
				case ParseScope.PLANE_2:
					if (token != "(")
					{
						if (token == ")")
						{
							componentIdx = 0;
							scope = ParseScope.TEXTURE;
						}
						else
						{
							switch (componentIdx)
							{
								case 0:
									currentFace.planePoints.v2.X = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 1:
									currentFace.planePoints.v2.Y = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 2:
									currentFace.planePoints.v2.Z = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
							}
							
							componentIdx++;
						}
					}
					
					break;
				case ParseScope.TEXTURE:
					currentFace.textureIdx = mapData.RegisterTexture(token);
					scope = ParseScope.U;
					break;
				case ParseScope.U:
					if (token == "[")
					{
						valveUVs = true;
						componentIdx = 0;
						scope = ParseScope.VALVE_U;
					}
					else
					{
						valveUVs = false;
						currentFace.uvStandard.X = token.ToFloat();
						scope = ParseScope.V;
					}

					break;
				case ParseScope.V:
					currentFace.uvStandard.Y = token.ToFloat();
					scope = ParseScope.ROT;
					break;
				case ParseScope.VALVE_U:
					if (token == "]")
					{
						componentIdx = 0;
						scope = ParseScope.VALVE_V;
					}
					else
					{
						switch (componentIdx)
						{
							case 0:
								currentFace.uvValve.U.axis.X = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
							case 1:
								currentFace.uvValve.U.axis.Y = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
							case 2:
								currentFace.uvValve.U.axis.Z = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
							case 3:
								currentFace.uvValve.U.offset = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
								break;
						}

						componentIdx++;
					}

					break;
				case ParseScope.VALVE_V:
					if (token != "[")
					{
						if (token == "]")
						{
							scope = ParseScope.ROT;
						}
						else
						{
							switch (componentIdx)
							{
								case 0:
									currentFace.uvValve.V.axis.X = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 1:
									currentFace.uvValve.V.axis.Y = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 2:
									currentFace.uvValve.V.axis.Z = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
								case 3:
									currentFace.uvValve.V.offset = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
									break;
							}

							componentIdx++;
						}
					}

					break;
				case ParseScope.ROT:
					currentFace.uvExtra.rot = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
					scope = ParseScope.U_SCALE;
					break;
				case ParseScope.U_SCALE:
					currentFace.uvExtra.scaleX = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
					scope = ParseScope.V_SCALE;
					break;
				case ParseScope.V_SCALE:
					currentFace.uvExtra.scaleY = (float)Convert.ToDouble(token, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
					CommitFace();
					scope = ParseScope.BRUSH;
					break;
			}
		}

		private void CommitEntity()
		{
			currentEntity.spawnType = EntitySpawnType.ENTITY;
			mapData.entities.Add(currentEntity);
			currentEntity = new Entity();
		}

		private void CommitBrush()
		{
			currentEntity.brushes.Add(currentBrush);
			currentBrush = new Brush();
		}

		private void CommitFace()
		{
			Vector3 v0v1 = currentFace.planePoints.v1 - currentFace.planePoints.v0;
			Vector3 v1v2 = currentFace.planePoints.v2 - currentFace.planePoints.v1;
			currentFace.planeNormal = v1v2.Cross(v0v1).Normalized();
			currentFace.planeDist = currentFace.planeNormal.Dot(currentFace.planePoints.v0);
			currentFace.isValveUV = valveUVs;
			
			currentBrush.faces.Add(currentFace);
			currentFace = new Face();
		}
	}
}


