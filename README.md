# Web cURLawler
Yet another tool to scan a website for directories and files.  It's written in Bash and uses cURL.  Developed using ChatGPT to see what it would toss out (which to my experience, never gets you something that works correctly) quickly as a base, and then manual tweaking to make it actually work.

**Usage:** ```./web_curlawler.sh -u https://domain.tld -w /path/to/wordlist.txt -e list,of,extensions```

I've got some weirdness with wordlists that have comment lines at the top.  Some, like the classic dirbuster wordlists, will try to recursively search on # infinitely, like it's not processing the # symbol correctly.  Others, including copying that exact text into a new file, totally fine, ignores it as the code intends.  So if you run into your wordlist trying to recursively search on #, go in and remove the comments from your wordlist.
