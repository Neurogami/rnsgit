rnsgit
===========

Tool to handle versioning a Renoise song in a local git repo.

Currently at the "works for me, mostly" stage.

The tool is a wrapper around [7z](http://www.7-zip.org/) and [git](http://git-scm.com/).

There is a very real possibility you will lose work.

The basic idea
--------------

A Renoise song is a `zip` file that contains an XML file of song details, and whatever samples are used in the song.  Maybe there's some other stuff as well, but it's a combination of binary data (the wavs or flacs or what have you) and text.

If you use git directly with this zip file you end up with (essentially) a complete copy of the song on every commit; that's just a problem of using binary files in certain change-control programs.

This ends up eating a good deal of disk space. You also cannot do useful things like cherry-pick changes or diff stuff to see just what was changed.  

In practice many songs changes do not change the binary data as often as the text data.  If you are not changing the song samples then your changes are probably happening in `Song.xml`.  Those are the changes that need fine-grain tracking.

The way to do this is to unzip the `xrns` file and place the individual files under git control. 

The problem is that you would have to manually unzip the song each time you wanted to commit changes.  If you wanted to roll back to an earlier song version, or change to a different branch, you would need to re-zip those files back into an `xrns` file.

The overall goal of `rnsgit` is to manage these actions.  The code is in the exploratory stage.  Be warned.

The code should:

* Create a repo if none exists
* Automatically update the `xrns` file when changing branches
* Automatically unzip and commit changes when (instructed)
* Try not to destroy anything


Usage
-----

This is one of many things in flux.  The current approach assumes you have a folder with a bunch of Renoise songs.  To "giterize" a song you would call the `rnsgit` script and pass in some command, maybe some options, and the song name.


For example:

     rnsgit init my-colossol-song.xrns   # Create a repo folder
     rnsgit ci "Now goes to 11"  my-colossol-song.xrns  # Unzip the xrns into the repo and commit the changes 
     rnsgit br super-amazing-radio-version  my-colossol-song.xrns # Switch branch and update the current xrns file 

An immediate need is to know that these things behave as expected and are not borking any song files.

The current code uses shell commands.  It's being developed on Ubuntu but needs to work on Windows as well.  (It should Just Work on OSX if it works on linux).  Since it is proxying calls to a local git setup it should be possible to have it respect whatever git abbreviations you have set up (e.g. `br` for `branch`, `ci` for `commit`).

There's a matter of designing for convenience, too.

Always passing in a song name can be tedious.  So there's a special command (`zip` or `pin`) that will create or update a local file named `.rnsgit`.  So far all it does is store a song file name.  But with that file in place you can then omit the song file name when calling the script.

The idea of having a default song is appealing because it makes usage a bit easier (and more like using git directly).

If the script were to behave just like git, with auto-zip/unzip in there as super colossal bonus behavior, this might make usage more intuitive to people used to git.

The script then would proxy all commands with some xrns-handling wrapping.  

But that's not what happens right now.  Maybe tomorrow.


Odds and ends
-------------

* Need to add better help so you know what works
* Need to change code so that all actual git commands work as expected (plus the magic xrns zip/unzip stuff)
* Renoise will not detect song file changes if, for example, you switch branches or revert some changes; pretty sure you will have to reload the song yourself

  

Features
--------

* Seems to work  
* If it does work then it provides versioning of your Renoise song while eliminating some of the zip/unzip drudgery


Requirements
------------

You must have [git](http://git-scm.com/) installed.

You must have [7z](http://www.7-zip.org/) installed.

You must have a zen-like acceptance of alpha code.



Install
-------

Grab the code from the repo, run `rake gem` and install the results.

You'll need the `bones` gem for this.  Probably other stuff as well.

Author
------


james Britt / Neurogami

License
-------

The MIT License

Copyright (c) 2015  James Britt / Neurogami

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


Hack your world.

Feed your head.

Live curious.
