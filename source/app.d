import std.stdio;
import std.string : fromStringz;
import std.json;
import std.conv;
import std.datetime.date : DateTime;
import std.array : join, replace;
import std.regex;
import std.net.curl;
import std.file;
import std.path;
import std.zip;
import std.array;

import VersionInfo;
import GitHub;
import PackageConfigure;
import FileUtils;

class Config
{
	static string config_filepath = "package.json";
}

void main()
{
	writeln("github release downloader");
	writefln("version: %s", VersionInfo.VersionInfo.VersionString);

	auto package_configure = new PackageConfigure.PackageConfigure(Config.config_filepath);
	package_configure.load();
	foreach (i, p; package_configure.packages)
	{
		auto info = p.info;

		auto repository = info.repository;
		auto install = info.install;
		auto filename = info.filename;
		const auto destination = info.destination;
		const auto rename = info.rename;

		auto github = new GitHub.GitHub();
		JSONValue[] res_doc = github.get_releases(repository);

		auto latest_release = res_doc[0];
		JSONValue[string] e = latest_release.object;
		const auto published_at = PackageConfigure.PackageConfigure.string_to_datetime(
				e["published_at"].str);
		JSONValue[] assets = e["assets"].array;
		foreach (a; assets)
		{
			JSONValue[string] n = a.object;
			string name = n["name"].str;

			string dir = "tmp";
			const auto match = matchFirst(name, filename);

			// | match | newer | !exists | download |
			// |-------|-------|---------|----------|
			// | false | false | false   | false    |
			// | false | false | true    | false    |
			// | false | true  | false   | false    |
			// | false | true  | true    | false    |
			// | true  | false | false   | false    |
			// | true  | false | true    | true     |
			// | true  | true  | false   | true     |
			// | true  | true  | true    | true     |
			if (match)
			{
				writeln(name);

				string dl_dest_path = buildPath(dir, name);
				if (!(install > published_at || !exists(dl_dest_path)))
				{
					break;
				}

				FileUtils.mkdir_if_not_exists(dir);

				string download_url = n["browser_download_url"].str;
				github.download(download_url, dl_dest_path);

				auto extract_to = destination.length > 0 ? destination : dir;
				FileUtils.mkdir_if_not_exists(extract_to);

				const auto file_type = FileUtils.analyze(dl_dest_path);
				write("file_tupe = ");
				writeln(file_type);
				auto result = false;
				switch (file_type)
				{
				case FileUtils.FileType.Zip:
					writefln("zip dir: %s", FileUtils.dirname_zip(dl_dest_path));
					if (rename.length > 0)
					{
						// extract to BaseDirectory
						result = FileUtils.extract_zip(dl_dest_path, dir);
						auto from_path = buildPath(dir, FileUtils.dirname_zip(dl_dest_path));
						auto to_path = buildPath(destination, rename);
						writefln("from = %s, to=%s", from_path, to_path);
						FileUtils.move_recurse(from_path, to_path);
					}
					else
					{
						result = FileUtils.extract_zip(dl_dest_path, extract_to);
					}
					break;
				case FileUtils.FileType.Exe:
					// fall through
				case FileUtils.FileType.Msi:
					result = FileUtils.execute(dl_dest_path, "");
					break;
				default:
					// download only
					result = true;
					break;
				}
			}
		}

		package_configure.packages[i].info.install = published_at;
	}

	package_configure.save();
}
