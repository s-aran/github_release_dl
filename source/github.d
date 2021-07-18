module GitHub;

import std.json;
import std.net.curl;
import std.array : join, replace;
import std.conv;
import std.string;
import std.stdio;

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
