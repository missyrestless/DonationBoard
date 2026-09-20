The Truth & Beauty Donation Board is a scripted single prim which accepts donation payments.

See https://github.com/missyrestless/DonationBoard#readme for the latest updated documentation.

Rez a Truth & Beauty Donation Board and position it where you want. It automatically configures as a donation board for the parcel in which it is rezzed. Set the donation board group and members of that group can login, the board automatically converting to a shared tip system.

On a group owned parcel, also rez the Truth & Beauty Stream Relay and deed it to the same group that owns the parcel.

Unlike other advanced tip jar and donation board systems, the Truth & Beauty Donation Board does not rely on an external 3rd party web service or website. You don't need anybody else's website to work.

Features
─────────

The Truth & Beauty Donation Board includes the following features:

- Easy to deploy, simply rez a board, grant debit privilege, and position it
    - Auto configures and is ready to accept donations without any additional steps
    - This default auto-configuration sends 100% of the donations to the owner of the board
- Donations can be split between a group member who is near the board and the owner
    - Easily converts between a parcel donation board and an event or DJ tip board
- The parcel stream URL will automatically change to the logged in user's setting
- All Truth & Beauty Donation Boards in the same region can be managed from any of them simultaneously
- A dialog menu can be used to further customize the board (see below for details)
- All configuration settings are stored in the prim's linkset datastore
    - No notecards to edit, customize via the dialog menu and settings are automatically saved
    - Customized settings persist across resets, deletions, updates, and more
- The board's front texture can be customized
    - The default front texture is the owner's profile pic
    - Select from any of the several textures provided to customize
    - Drag and drop any texture into the prim Contents to add that texture to the dialog menu Texture options
- A particle display is emitted when rezzed/reset and when a donation is made
- The LSL scripts are low lag and have been optimized with 'LSL-PyOptimizer'
- The scripts are Open Source and can be viewed, copied, and modified freely within the terms of the license

Setup
──────

The Truth & Beauty Donation Board auto-configures when rezzed and is active immediately.

There are no notecards to edit, all configuration is maintained in the prim's linkset datastore.

It is necessary to give the board permission to take money in order to support the sharing feature. You MUST allow it for the board to work if you want to share donations.

Splitting Donations
────────────────────

The Truth & Beauty Donation Board is configured to split donations between the owner and a logged in user.

In order for the donation splitting feature to work, the request for Debit permission must have been accepted.

If Debit permission is denied then the board will still function but splitting donations will be disabled.

Using the Board on Group Owned Land
────────────────────────────────────

In order to use the Truth &amp; Beauty Donation Board on group owned land, the Truth & Beauty Stream Relay object must be rezzed on the parcel. Once rezzed, deed the Stream Relay to the same group that owns the parcel.

The Truth & Beauty Stream Relay can be rezzed to determine if the parcel is deeded to a group. A message will be sent to the owner informing them of the status and required action, if any.

Individually owned parcels
───────────────────────────

If you are the owner of the parcel ("About Land" shows you as the owner), no additional configuration is needed.

Group owned parcels
────────────────────

If "About Land" shows the name of a group as owner, the parcel is group owned. In this case, you need to rez and deed the Stream Relay object to the group.

Dialog Menu
────────────

By default the board will be configured to accept a donation (Pay) when clicked. The owner or members of the board's group can access a setup menu by touching the board. To touch the board when Pay is set for click, it is necessary to right click the board and select Touch. Right clicking and selecting Touch will open a dialog menu with buttons to further customize the Donation Board.

The main menu includes the following buttons:

- START
- INFO
- STOP
- SOLO
- ALL
- OWNER
- GROUP
- LOGIN
- LOGOUT
- AMOUNTS
- CLEAR
- DISTANCE
- HOVER TXT
- SHARE
- TEXTURE
- TOTAL
- DEBUG
- EXIT
