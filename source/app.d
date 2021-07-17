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

static const string Version = "0.10";

struct PackageInfo
{
	string repository;
	DateTime install;
	string filename;
	string destination;
}

struct Package
{
	string name;
	PackageInfo info;
}

class Config
{
	static string config_filepath = "package.json";
}

class PackageConfigure
{
	private string path;
	Package[] packages;

	this(string filepath)
	{
		this.path = filepath;
	}

	void load()
	{
		if (!exists(this.path) || !isFile(this.path))
		{
			throw new Exception("File not found: " ~ this.path);
		}

		auto file = File(this.path, "rb");
		auto content = file.rawRead(new char[file.size]);
		file.close();

		auto json = parseJSON(content).object;
		this.build(json);
	}

	void save()
	{
		if (!exists(this.path) || !isFile(this.path))
		{
			throw new Exception("File not found: " ~ this.path);
		}

		auto file = new File(this.path, "w");
		auto json = this.to_json(this.packages);
		file.write(json.toPrettyString());
		file.close();
	}

	private void build(JSONValue[string] document)
	{
		foreach (key, value; document)
		{
			JSONValue[string] item = value.object;
			string repository = item["repository"].str;

			string install_str = "";
			if ("install" in item)
			{
				install_str = item["install"].str;
			}
			DateTime install = this.string_to_datetime(install_str);
			string filename = item["filename"].str;

			string destination = "";
			if ("destination" in item)
			{
				destination = item["destination"].str;
			}

			auto info = PackageInfo(repository, install, filename, destination);
			auto pkg = Package(key, info);
			this.packages ~= pkg;
		}
	}

	private JSONValue to_json(Package[] packages)
	{
		auto result = JSONValue((JSONValue[string]).init);

		foreach (p; packages)
		{
			auto info = p.info;

			auto item = JSONValue((JSONValue[string]).init);
			item["repository"] = info.repository;
			item["install"] = info.install.toISOExtString();
			item["filename"] = info.filename;
			item["destination"] = info.destination;

			result[p.name] = item;
		}

		return result;
	}

	static DateTime string_to_datetime(string s)
	{
		// remove 'Z' (YYYY-MM-DDThh:mm:ssZ -> YYYY-MM-DDThh:mm:ss)
		return s.length > 0 ? DateTime.fromISOExtString(s.replace("Z", "")) : DateTime();
	}

}

class GitHub
{
	private string create_url(string repository)
	{
		return join(["https:/", "api.github.com/repos", repository, "releases"], "/");
	}

	JSONValue[] get_releases(string repository)
	{
		auto client = HTTP();
		client.addRequestHeader("Accept", "application/vnd.github.v3+json");

		auto release_url = this.create_url(repository);
		char[] res = get(release_url, client);
		string sres = to!string(res);

		return parseJSON(sres).array;
	}

	bool download(string browser_download_url, string to)
	{
		auto client = HTTP();
		write(browser_download_url);
		std.net.curl.download(browser_download_url, to, client);
		writeln(" ... Done");
		return true;
	}
}

class FileUtils
{
	const string BaseDirectory = "tmp";

	static bool mkdir_if_not_exists(string pathname)
	{
		if (!exists(pathname))
		{
			mkdirRecurse(pathname);
		}
		return true;
	}

	static bool extract_zip(string path, string to)
	{
		if (!exists(path) || !isFile(path))
		{
			return false;
		}

		auto zip = new ZipArchive(read(path));
		foreach (name, am; zip.directory)
		{
			if (am.expandedSize == 0 && am.crc32 == 0)
			{
				// Directory
				mkdirRecurse(name);
			}
			else
			{
				auto extract_dest = buildPath(to, name);

				writefln(" ... %s", name);
				auto p = dirName(extract_dest);
				if (!exists(p))
				{
					mkdirRecurse(p);
				}

				auto f = File(extract_dest, "wb");
				f.rawWrite(zip.expand(am));
				f.close();

				if (am.expandedData.length != am.expandedSize)
				{
					return false;
				}
			}
		}

		return true;
	}
}

void main()
{
	writeln("github release downloader");
	writefln("version: %s", Version);

	auto package_configure = new PackageConfigure(Config.config_filepath);
	package_configure.load();
	foreach (i, p; package_configure.packages)
	{
		auto info = p.info;

		auto repository = info.repository;
		auto install = info.install;
		auto filename = info.filename;
		const auto destination = info.destination;

		auto github = new GitHub();
		JSONValue[] res_doc = github.get_releases(repository);

		auto latest_release = res_doc[0];
		JSONValue[string] e = latest_release.object;
		const auto published_at = PackageConfigure.string_to_datetime(e["published_at"].str);
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
				FileUtils.extract_zip(dl_dest_path, extract_to);
			}
		}

		package_configure.packages[i].info.install = published_at;
	}

	package_configure.save();
}
