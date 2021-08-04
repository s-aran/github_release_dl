module GitHub;

import std.json;
import std.net.curl;
import std.array : join, replace;
import std.conv;
import std.string;
import std.stdio;
import std.format;
import core.stdc.stdlib: exit;

import Logger;

class GitHub
{
	private string create_url(string repository)
	{
		return join(["https:/", "api.github.com/repos", repository, "releases"], "/");
	}

	JSONValue[] get_releases(string repository)
	{
		auto logger = EzLogger.get_logger("http");

		auto client = HTTP();
		client.addRequestHeader("Accept", "application/vnd.github.v3+json");

		auto release_url = this.create_url(repository);

		try
		{
			char[] res = get(release_url, client);
			string sres = to!string(res);
			return parseJSON(sres).array;
		}
		catch (std.net.curl.HTTPStatusException e)
		{
			logger.fatal(format("%s:%d: %s", e.file, e.line, e.msg));
			exit(255);
		}
	}

	bool download(string browser_download_url, string to)
	{
		auto logger = EzLogger.get_logger("http");

		auto client = HTTP();
		logger.info(browser_download_url);
		std.net.curl.download(browser_download_url, to, client);
		logger.info(" ... Done");
		return true;
	}
}
