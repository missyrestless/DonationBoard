# Truth &amp; Beauty Donation Board

The Truth &amp; Beauty Donation Board is a scripted single prim which accepts donation payments.

Rez a Truth &amp; Beauty Donation Board and position it where you want. It automatically configures as a donation board for the parcel in which it is rezzed. Set the donation board group and members of that group can login, the board automatically converting to a shared tip system.

Rez as many boards as you need, they are Copy/Modify and only a single prim.

Unlike other advanced tip jar and donation board systems, the Truth &amp; Beauty Donation Board does not rely on an external 3rd party web service or website. All functionality is implemented in the board's scripts and will continue to function without dependence on anyone else or any service maintained by others.

## Marketplace

The Truth &amp; Beauty Donation Board is available on the [Second Life Marketplace](https://marketplace.secondlife.com/p/Truth-Beauty-Donation-Board/28680959).

## Features

The Truth &amp; Beauty Donation Board includes the following features:

- Easy to deploy, simply rez a board, grant debit privilege, and position it
    - Auto configures and is ready to accept donations without any additional steps
    - This default auto-configuration sends 100% of the donations to the owner of the board
- Donations can be split between a group member who is near the board and the owner
    - Easily converts between a parcel donation board and an event or DJ tip board
- The parcel stream URL will automatically change to the logged in user's setting
- All Truth &amp; Beauty Donation Boards in the same region can be managed from any of them simultaneously
- A dialog menu can be used to further customize the board (see below for details)
- All configuration settings are stored in the prim's linkset datastore
    - No notecards to edit, customize via the dialog menu and settings are automatically saved
    - Customized settings persist across resets, deletions, updates, and more
- The board's front texture can be customized
    - The default front texture is the owner's profile pic
    - Select from any of the several textures provided to customize
    - Drag and drop any texture into the prim Contents to add that texture to the dialog menu Texture options
- A particle display is emitted when rezzed/reset and when a donation is made
- The `DonationBoard` and `DialogMenu` LSL scripts are low lag and have been optimized with `LSL-PyOptimizer`
- The `DonationBoard` and `DialogMenu` scripts are Open Source and can be viewed, copied, and modified freely within the terms of the license

## Setup

The Truth &amp; Beauty Donation Board auto-configures when rezzed and is active immediately.

There are no notecards to edit, all configuration is maintained in the prim's linkset datastore.

It is necessary to give the board permission to take money in order to support the sharing feature. You MUST allow it for the board to work if you want to share donations. The permission popup will be displayed when the board is rezzed and any time it is reset. Accept the permission request, this is a standard part of any object that takes payments.

### Deeding the Board on Group Owned Land

The Truth &amp; Beauty Donation Board can set the parcel music stream URL. In order to do so, the board must be owned by the same owner as the land. If the parcel has been deeded to a group then the Donation Board must also be deeded to the same group.

#### Individually owned parcels

If you are the owner of the parcel ("About Land" shows you as the owner), no additional configuration is needed.

#### Group owned parcels

If "About Land" shows the name of a group as owner, the parcel is group owned. In this case, you need to deed the Donation Board object to group.

##### Group Deeding

If your parcel is owned by a group, but does not have group deeding enabled, you need to ask the owner of your land to enable group deeding.

##### Set the Donation Board Group

First, make sure the board belongs to the correct group. The owner can right-click the board and select Edit. If the Group: setting in the General tab of the Edit window is set to a group different than that shown in "About Land" then click the wrench icon to the right of the Group: setting. Select the group to use in the Group chooser popup.

##### Deed the Donation Board to the Group

Once the desired group is set, click the Share checkbox below the group in the Edit window. Click the Deed button and Close the Edit window (Edit → General → Share [checkbox] → Deed).

##### Summary of Group Deeding

If the parcel is owned by an individual then no group configuration is necessary.

If the parcel is group owned:

- The board must be set to the desired group
- Group deeding must be enabled on the parcel
- The board must be deeded to that group

If unable to deed the board, it will still work but the parcel stream URL management function will be disabled.

**[Note:]** It is recommended to take a copy of the Donation Board back into your inventory **Before Deeding** it to a group. This makes it easier to modify the board later if needed and ensures you will always have a copy to re-deed if necessary.

## Dialog Menu

By default the board will be configured to accept a donation (Pay) when clicked. The owner or members of the board's group can access a setup menu by touching the board. To touch the board when Pay is set for click, it is necessary to right click the board and select Touch. Right clicking and selecting Touch will open a dialog menu with buttons to further customize the Donation Board.

The main menu includes the following buttons:

- **START**
    - Activate an idle Donation Board
    - When the board is in the active state a click will open a payment dialog
- **INFO**
    - Report the status and location of all Donation Boards in the region
- **STOP**
    - Deactivate the Donation Board and enter the idle state
    - When the board is in an idle state a click will open the dialog menu
- **SOLO**
    - Menu actions effect ONLY THIS BOARD
- **ALL**
    - Menu actions effect ALL BOARDS IN REGION
- **OWNER**
    - Owner only access
- **GROUP**
    - Allow group members to login/manage the boards
- **LOGIN**
    - Login to the board as a DJ or event coordinator
- **LOGOUT**
    - Exit role as DJ or event coordinator, board reverts to accepting parcel donations
    - Leaving the area will automatically logout any logged in user
- **AMOUNTS**
    - Set the suggested amounts in the Pay popup, including the default pay amount
- **CLEAR**
    - Clear all stored configuration and reset to original state
- **DISTANCE**
    - Set the maximum distance a logged in user can be before being logged out
- **HOVER TXT**
    - Set the Board name hover text
- **SHARE**
    - Set the percentage of donation shared with logged in group member
- **TEXTURE**
    - Open the Board texture menu
- **TOTAL**
    - Toggle display of total donations in hover text
- **DEBUG**
    - The owner can enable debug mode to receive additional messages
- **EXIT**
    - Exit the Dialog Menu

## Splitting Donations

The Truth &amp; Beauty Donation Board is configured to split donations between the owner and a logged in user.

In order for the donation splitting feature to work, the request for Debit permission must have been accepted.

If Debit permission is denied then the board will still function but splitting donations will be disabled.

Members of the board's group can login by touching the board.

Only the owner can manage the tip sharing features such as specifying the share percentage, configuring the board's group, and enabling/disabling sharing via the dialog menus.

Once the board group is configured and on group owned land the board has been deeded to the group, enable the group sharing feature of the board by right-clicking the board and selecting Touch. In the main dialog menu, click GROUP. Members of the configured group can now login by touching the board and donations will be split between the owner and logged in user.

### Configure the share percentage

The owner can modify the donation percent shared with logged in users by opening the dialog menu (right-click the board and select Touch). In the main menu, click SHARE. An input text box will be opened displaying the currently configured share percentage. To change this, enter the desired percent to be sent to the logged in user and click Submit.

### Summary of Donation Sharing

- Debit permission must be granted
- Group sharing must be enabled by clicking the GROUP menu button
- Percent split to the logged in user can be configured (default: 80%)
- Group members must wear the group tag in order to login
- Leaving the area will logout the user
