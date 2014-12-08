gelly
=====

booru client in vala

Welcoming contributors! If you'd like to join the project feel free to make issues to discuss things or anything.

<img src="http://i.imgur.com/kmc97kJ.png"></img>


Notes
=====

It doesn't use threading yet so it will stop for a bit when you do a search.


Code Overview
=============

The entry point `main` starts Gtk and makes a new "Uru" object which is a window.

Uru builds the GUI and sets actions (signals) for the buttons.

The only action just now is to `perform_search` which uses the XML API to get a list of posts with the tags you are after.

Then it fills the GUI up using `process_search_results`. It builds a `Post` struct for each XPath result and then puts that into the list. 


TODO list
=========
* handle pages

Usability:
* image size [requires an extra get]
* make the search happen threaded so images appear one by one
* add a loading bar for the search

Downloading images:
* add a marker that shows when an image is already saved
* add a loading bar or status bar telling you when its downloading an image
