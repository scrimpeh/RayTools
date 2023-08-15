// Heatmap merger
// Takes a number of files as input arguments and creates a heatmap. Reports duplicates

int DuplicateCount = 0;

void Merge(IDictionary<Offset, Speed> heatmap, string file)
{
	Console.WriteLine($"Reading file '{file}'...");
	foreach (var line in File.ReadAllLines(file))
	{
		var values = line.Split(',')
			.Select(int.Parse)
			.ToList();
		var offset = new Offset(values[0], values[1]);
		var speed = new Speed(values[2], values[3]);
		if (heatmap.ContainsKey(offset) && speed != heatmap[offset]) {
			DuplicateCount++;
			if (DuplicateCount < 10)
				Console.WriteLine(
					$"Warning! Found non-matching duplicate in file '{file}'!\n" +
					$"Position: {offset.X} / {offset.Y}\n" +
					$"Previous: {heatmap[offset].X} / {heatmap[offset].Y}\n" +
					$"New {speed.X} / {speed.Y}"
				);
			// Simple heuristic: Pick speed boost with larger absolute value
			var oldVelocity = Math.Abs(heatmap[offset].X) + Math.Abs(heatmap[offset].Y);
			var newVelocity = Math.Abs(speed.X) + Math.Abs(speed.Y);
			if (newVelocity > oldVelocity)
				heatmap[offset] = speed;
		}
		else
			heatmap[offset] = speed;
	}
}

// Entry Point

if (!args.Any())
{
	Console.WriteLine("Usage 'heatmapmerger <outputfile> <file...>'");
	return 1;
}

// Read files

var outputFile = args[0];
var heatmap = new Dictionary<Offset, Speed>();

foreach (var file in args.Skip(1))
	Merge(heatmap, file);

// Output into new file
Console.WriteLine($"Writing file '{outputFile}'...");
using var writer = new StreamWriter(outputFile);
var records = heatmap
	.OrderBy(s => s.Key.X)
	.ThenBy(s => s.Key.Y);
foreach (var (offset, speed) in records)
	writer.WriteLine($"{offset.X},{offset.Y},{speed.X},{speed.Y}");

Console.WriteLine($"Read {args.Length - 1} file(s), detected {DuplicateCount} duplicate(s).");
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
