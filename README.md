# Truth &amp; Beauty Donation Board

The Truth &amp; Beauty Donation Board is a scripted single prim which accepts donation payments.

Rez a Truth &amp; Beauty Donation Board and position it where you want.

Rez as many boards as you need, they are Copy/Modify.

## Features

The Truth &amp; Beauty Donation Board includes the following features:

- Easy to deploy, simply rez a board, grant debit privilege, and position it
    - Auto configures and is ready to accept donations without any additional steps
    - This default auto-configuration sends 100% of the donations to the owner of the board
- Donations can be split between a group member who is near the board and the owner
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
- The `DonationBoard` and `DialogMenu` LSL scripts are low lag and have been optimized with `PyOptimizer`
- The `DonationBoard` and `DialogMenu` scripts are Open Source and can be viewed, copied, and modified freely within the terms of the license

## Marketplace

The Truth &amp; Beauty Donation Board is available on the [Second Life Marketplace](https://marketplace.secondlife.com/stores/44210).

## Setup

The Truth &amp; Beauty Donation Board auto-configures when rezzed and is active immediately.

There are no notecards to edit, all configuration is maintained in the prim's linkset datastore.

It is necessary to give the board permission to take money in order to support the sharing feature. You MUST allow it for the board to work if you want to share donations. The permission popup will be displayed when the board is rezzed and any time it is reset. Accept the permission request, this is a standard part of any object that takes payments.

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
    - Allow group members to manage the boards
- **BOARD NAME**
    - Set the Board name hover text
- **TEXTURE**
    - Open the Board texture menu
- **EXIT**
    - Exit the Dialog Menu
