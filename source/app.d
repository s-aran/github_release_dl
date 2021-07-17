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

void main()
{
	JSONValue[string] document = parseJSON(`{
	"vim_win32_installer" : 
		{
			"repository" : "vim/vim-win32-installer",
			"install" : "2013-02-27T19:35:32Z",
			"filename" : "^gvim_.*_x64.zip$",
			"destination": "M:\\app\\"
		}
	}`).object;

	foreach (json; document)
	{
		JSONValue[string] p = json.object;

		string repository = p["repository"].str;
		string install = p["install"].str;
		string filename = p["filename"].str;
		string destination = p["destination"].str;

		// remove 'Z' (YYYY-MM-DDThh:mm:ssZ -> YYYY-MM-DDThh:mm:ss)
		auto dt = DateTime.fromISOExtString(install.replace("Z", ""));

		auto info = PackageInfo(repository, dt, filename, destination);

		writeln(info);
		writeln(dt);

		// auto req = Request();
		// req.addHeaders(["Accept": "application/vnd.github.v3+json"]);
		auto release_url = join([
				"https:/", "api.github.com/repos", repository, "releases"
				], "/");
		writeln(release_url);

		auto client = HTTP();
		client.addRequestHeader("Accept", "application/vnd.github.v3+json");
		// auto res = post(release_url, [], client);
		char[] res = get(release_url, client);
		string sres = to!string(res);
		JSONValue[] res_doc = parseJSON(sres).array;

		auto latest_release = res_doc[0];

		JSONValue[string] e = latest_release.object;
		JSONValue[] assets = e["assets"].array;
		foreach (a; assets)
		{
			JSONValue[string] n = a.object;
			string name = n["name"].str;

			string dir = "tmp";
			auto match = matchFirst(name, filename);
			if (match)
			{
				writeln(name);

				if (!exists(dir))
				{
					mkdir(dir);
				}
				// string p = buildPath("tmp", name);
				// mkdirRecurse(p);

				string download_url = n["browser_download_url"].str;
				string dl_dest_path = buildPath(dir, name);
				download(download_url, dl_dest_path, client);

				if (exists(dl_dest_path) && isFile(dl_dest_path))
				{
					auto zip = new ZipArchive(read(dl_dest_path));
					foreach (aname, am; zip.directory)
					{
						// writefln("%10s  %08x  %s", am.expandedSize, am.crc32, aname);

						if (am.expandedSize == 0 && am.crc32 == 0)
						{
							// Directory
							mkdirRecurse(aname);
						}
						else
						{
							auto extract_dest = buildPath(dir, aname);
							writefln(aname);
							auto p = dirName(extract_dest);
							if (!exists(p))
							{
								mkdirRecurse(p);
							}
							auto f = File(extract_dest, "wb");
							f.rawWrite(zip.expand(am));
							f.close();
							assert(am.expandedData.length == am.expandedSize);
						}
					}
				}
			}
		}

		// writeln(res.code);
		// writeln(res.responseBody);
	}
}
