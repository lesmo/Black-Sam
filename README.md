# Black Sam
## Why?
The Internet's pretty useful, but different agents are making it more and more difficult for people to access information: data and media censored by big corporations and governments for lots of reasons (many pretty ridiculous). Centralization of that makes it utterly simple to take down things, just take The Pirate Bay as the most recent example. Everyone thinks The Pirate Bay is just there to allow you to get the latest album of your favorite artist without paying, or that episode of that TV show your french friend told you about, but it isn't... _piracy_ is about freedom.

There are torrents out there with valuable information about corrupt companies and governments, survival, advice, and a valuable way for indie photographers, directors, musicians and game developers to share and distribute their work. Human development could be buried there... why stop that from happening?

## What is it?
**BlackSam** is a _simple_ torrent search and management software (like that used on The Pirate Bay, Iso Hunt or similar) for **Node.js** you can quickly get up and running in your computer, server or cloud service, _**without any database**_. This effectively allows to share, browse, edit and restore the entire "database" of torrents easily.

It supports a built-in mechanism of _decentralized synchronization_ that doesn't require authentication of everyone involved. As long as the _fleet_ (or swarm of servers, whatever you want to call it) you want to join allows it, you can effectively get up and running in minutes (depending on the database's size).

## How do I install it?
You can't. It's not ready yet.

## How does it work?
Where do we store all data? In the File System, obviously. All data is stored in a subdirectory where **BlackSam** is installed, which is named -you guessed it- ```marianne``` . Oh, you didn't guess it? That's [a name for the goddess of freedom](http://en.wikipedia.org/wiki/Marianne), and also the name of the first ship _Black Sam_ sailed as captain.

### User management
When a user registers, a new directory is created inside the ```marianne``` directory with the name of the RIPEMD-160 hash of the SHA-256 hash of the SHA-512 of the username and password, prefixed with ```1-```, called _User Hash_:

 ```
 "1-" + ripemd(sha256(sha512(<username> + <password>)))
 ```
 
The ```1-``` prefix is the _User Hash Version_. If in future releases new and better mechanisms are implemented, this prefix can be changed to anything else to accommodate that change.

Because of the way **BlackSam** keeps all _Ships_ (or _nodes_ for non-pirate lads) in sync, users cannot change their username or password (see Replication section for details). This means the user will login with a _username_ and _password_ combination that can still be anonymous, and is nearly impossible crack or guess. This also means that there is effectively no password reset available at all, and one is very likely to never be implemented.

Other files provide more data for **BlackSam**'s behaviour, but because of the "create only" nature of it's sync methods, once they're created they cannot be deleted. Some mechanisms allow **BlackSam** to validate all ```user.*``` files, so adversaries cannot create a _Denial of Service_ on any user.

#### user.json
If a user chooses to be displayed as the uploader of her torrents, **BlackSam** can create a _JSON_ file named ```user.<display name>.json``` with _metadata_ about her. Different information can be inside, but for now only ```seedhash``` with the SHA-256 hash of the username and password combined as value is used.

When a user requests a new username and password combination, and the user decides she'd like to keep her _Display Name_, the previous account is locked and the metadata file is re-created in the new _User Hash_ directory, preventing anyone from registering the old _Display Name_ while this process occurs. **BlackSam** _Ships_ will recognize this behaviour and delete local ```user.<display name>.json``` files.

If a ```user.<display name>.json``` file is created all uploads by that user will show a "by <user name>" label under the Torrent on search results and browse sections. If the upload is not _signed_, a warning icon will be shown next to it; correctly _signed_ uploads will show a green tick mark instead, along with a link to retrieve the public key and the signature validated by **BlackSam**.

#### user.pem
For authentication of Torrent contributions when users choose to do so, a public-key file ```user.pem``` can be created when the user generates one on her browser, or uploads one if opted for creating it offline.

Because **BlackSam** is trying to stick as much as possible to pure **Node.js**, [only a subset](http://kjur.github.io/jsrsasign/) of ```*.pem``` file formats and algorithms are supported.

#### user.sig
The only way of authenticating a _Public Key_ ```user.pem``` file is actually one uploaded by the user, a ```user.sig``` file must be created with the signature of the ```user.<display name>.json``` file.

#### user.lock
A ```user.lock``` file containing the SHA-512 hash of the username and password combined can be created to make **BlackSam** ignore any new data for that user, "locking down" that account. A _pointer_ to the new account _(User Folder)_ can be stored to be able to link accounts as the same entity, but it can be skipped.

```
<sha512(username + password)>:<new account hash>
```

All ```user.*``` files, except for this one, are deleted when this file is found and is valid.

### Torrent storage
When a user uploads a _Torrent File_ or a _Magnet Link_, **BlackSam** creates 3 files inside the uploader's _User Hash_ directory. _Metafiles_'s hash (seen in  _Magnet Links_) are used as the name for these 3 files.

#### {hash}.torrent
Before accepting a Torrent to be stored, it is checked to be a valid Torrent with at least 1 seeder. Torrents with no seeds are not stored, and Torrents that were accepted before are deleted if they've got no seeders when the cleanup is ran (which is ran, by default, once a week).

_Torrent Files_ can be generated by a _Magnet Link_, and viceversa.

#### {hash}.md
**BlackSam** allows the use of [Markdown Files](https://github.com/evilstreak/markdown-js) to create descriptions for _Torrent Files_. During upload it can try to find ```README```, ```*.nfo```, ```*.md``` and ```README``` files inside the Torrent to pre-generate this description.

#### {hash}.json
For the purposes of the Search Indexing and metadata keeping, **BlackSam** creates a _JSON file_ with the Torrent's file location, title, indexing string (taken from the Markdown stripped from any symbols and short words), category and seed-leech counts.

#### {hash}.sig
During upload a user can sign the _contribution_ to let everyone know that an upload is _authentic_. For this purpose, **BlackSam** uses _Asymmetric Key Signatures_ that can be relatively easy to set up by the user.

### Search
[Search-index module](https://github.com/fergiemcdowall/search-index) is used to provide the search functionality. **BlackSam** feeds to it all the Torrent's _JSON Files_ described above. That's pretty much it.

An _Index Directory_ is created, named ```sherlock``` (everybody knows who he is) because why not, where the **Search Index** is to be stored.

### Replication
The most importart part of this whole thing, is accomplished by using [Telehash](https://github.com/telehash/telehash-js), a DHT implementation (similar to that used by Gnutella protocol, and the BitTorrent protocol itself).

**BlackSam** will distributes changes between all _Ships_ (or _nodes_ for non-pirate lads), making sure everyone is in sync. When new changes are available, all _Ships_ will receive a _Telegram_ telling them about a new tracker-less Torrent with new files to download. Each _Ship_ will validate the Torrent contents and only download files it doesn't already have.

Every _Ship_ is capable of _**adding new files**_ to all _Ships_ _**but not delete nor overwrite anything**_. **BlackSam** runs cleanup tasks that ensure that only working torrents exist in it's _database_, but deletions are not propagated to everyone; each node is responsible of deciding if a torrent should be removed. Thus, **BlackSam** users cannot delete any torrent they've added, nor change their user name, password, display-name or metadata (at least directly).

## How resilient is it?
Adversaries can join the network, and employ well-known [attacks on the BitTorrent protocol](#) and [other DHT related attacks](#). There isn't much **BlackSam** can do there, except for validating ```marianne``` files cryptographic integrity and _Torrent Files_ validity during sync.

They also can, for example, _Telegram_ an invalid _Torrent Metadata Hash_ (unexistant, invalid or with no seeds), or one that is valid but doesn't contain any data **BlackSam** can understand (a Torrent with photos, perhaps), or a valid one with huge files (like _The Interview_ movie for example), or a valid Torrent with valid directory structure and file extensions, but corrupted or obnoxiously large files.

**BlackSam** can detect these kinds of problems and ignore those Torrents as it goes. However, repeated attempts of this could potentially slow down the sync process for various _Ships_, but they would still be able to fully sync eventually. A future version will implement a _Trusted Ships_ mechanism that will let certain long-running and "trusted" _Ships_ to distribute _Black Lists_, new _Trusted Ships_, among other things.

## But...
Yeah, there's always _buts_. Here, hopefully you'll be satisfied with:

### ... why Black Sam?
Simple. **Samuel Bellamy**, known as **[Black Sam](http://en.wikipedia.org/wiki/Samuel_Bellamy)**, is considered the #1 top-earning pirate of all times according to [Forbes](http://www.forbes.com/2008/09/18/top-earning-pirates-biz-logistics-cx_mw_0919piracy.html), and also regarded by his crew as "The Robin Hood of the Seas". He's known to believe he wasn't harming anyone through his actions as a pirate, but rather as merely taking back what others had stolen through the exploitation of the people. And not only that, he was also known to held _very_ democratic (at least for his times) rules for his crew.

It just so happens that this project has (hopefully) those -and probably more- things in common with him.

### ... why Node.js?
There's already [Isohunt's OpenBay](https://github.com/isohuntto/openbay) effort to create something very similar to this, and it would probably be easier to use build on top of that. However, using PHP might not be as simple for many users to use and setup locally as this project's trying to be. Not to mention that the possibility of a Node-Webkit application is very promising.
