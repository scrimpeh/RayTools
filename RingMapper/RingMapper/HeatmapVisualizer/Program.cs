// Heatmap Visualizer
// Takes a heatmap as input and a few parameters and generates a PNG to draw from it

#pragma warning disable CA1416 // Validate platform compatibility

using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

int XMin = int.MinValue;
int XMax = int.MaxValue;
int YMin = int.MinValue;
int YMax = int.MaxValue;

Color GetColor(Speed speed)
{
	static int Cap(double value)
		=> Math.Min(Math.Max(0, (int) value), 255);

	if (speed.X < -48 || speed.X > 48)
		return Color.FromArgb(0xC0, Color.Red);

	// Remap speed from [-48;47] to [0,255]
	var xs = (speed.X + 48) * (255.0 / 96.0);
	var absX = Math.Abs(speed.X);

	var alpha = absX > 5 ? 0xC0 : (absX + 5) / 10.0 * 0xC0;
	var red = xs;
	var green = xs;
	var blue = xs;
	return Color.FromArgb(Cap(alpha), Cap(red),Cap(green),Cap(blue));
}

bool Show(Speed speed)
	=> speed.X >= XMin && speed.X <= XMax &&
	   speed.Y >= YMin && speed.Y <= YMax;

// Entry Point

if (args.Length <= 1)
{
	Console.WriteLine("Usage 'heatmapvis <file> <outputFile> (-xmin <x>)? (-xmax <x>)? (-ymin <y>)? (-ymax <y>)?");
	return 1;
}

Console.WriteLine("Starting Heatmap Visualizer");

string file = args[0];
string outputFile = args[1];
if (!File.Exists(file))
{
	Console.WriteLine($"File '{file}' doesn't exist!");
	return 1;
}

// Parse Args
for (var i = 2; i < args.Length; i++)
{
	switch (args[i])
	{
		case "-xmin":
			XMin = int.Parse(args[i + 1]);
			break;
		case "-xmax":
			XMax = int.Parse(args[i + 1]);
			break;
		case "-ymin":
			YMin = int.Parse(args[i + 1]);
			break;
		case "-ymax":
			YMax = int.Parse(args[i + 1]);
			break;
	}
}

// Read Heatmap
var heatmap = new Dictionary<Offset, Speed>();
Console.WriteLine($"Reading file '{file}'...");
foreach (var line in File.ReadAllLines(file))
{
	var values = line.Split(',')
		.Select(int.Parse)
		.ToList();
	var offset = new Offset(values[0], values[1]);
	var speed = new Speed(values[2], values[3]);
	heatmap[offset] = speed;
}

// Find Bounds
var minX = heatmap.Keys.Min(offset => offset.X);
var maxX = heatmap.Keys.Max(offset => offset.X);
var minY = heatmap.Keys.Min(offset => offset.Y);
var maxY = heatmap.Keys.Max(offset => offset.Y);

var width = maxX - minX + 1;
var height = maxY - minY + 1;

// Create image
using var bitmap = new Bitmap(width, height);
using var graphics = Graphics.FromImage(bitmap);
graphics.CompositingMode = CompositingMode.SourceCopy;
graphics.FillRectangle(Brushes.Transparent, new(0, 0, width, height));

foreach (var (offset, speed) in heatmap.Where(kv => Show(kv.Value)))
	bitmap.SetPixel(offset.X - minX, offset.Y - minY, GetColor(speed));

bitmap.Save(outputFile, ImageFormat.Png);


Console.WriteLine("Done");
return 0;

// Struct definitions

readonly record struct Offset
{
	public int X { get; }
	public int Y { get; }

	public Offset(int x, int y)
	{
		X = x;
		Y = y;
	}
}

readonly record struct Speed
{
	public int X { get; }
	public int Y { get; }

	public Speed(int x, int y)
	{
		X = x;
		Y = y;
	}
}