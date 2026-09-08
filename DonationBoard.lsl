///////////////////////////////////////////////////////////////////////////////////
//     Donation Board LSL script with Pay/Touch or Message on Listen Channel     //
//                                                                               //
// Message or Touch by owner of object toggles Menu and Payment states           //
// Listens on channel 0 for trigger messages to board                            //
// Messages other boards in region with same owner to trigger toggle command     //
///////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
// Copyright (c) 2026 Truth & Beauty Lab          //
// License: GPLv3                                 //
// All rights reserved.                           //
//                                                //
// Author: Missy Restless missyrestless@gmail.com //
////////////////////////////////////////////////////

////////////////////////////////////////////////////
//            Modification History                //
//            --------------------                //
// 2026-Sep-07 Created                            //
// 2026-Sep-08 All linkset data store and menu    //
//                                                //
////////////////////////////////////////////////////

string   VERSION = "1.0.1";

integer  ALL     = TRUE;      // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP   = FALSE;     // Set to TRUE to allow group members to manage, FALSE for owner only
integer  listenerID;
integer  objListenID;
integer  dialogHandle;
integer  warnHandle;
integer  dialogChannel;
integer  objChannel;           // Channel for communication between screens, based on owner
integer  listenChannel  = 0;   // Channel for chat and gestures
integer  LoggedIn       = FALSE;
integer  pageNumber     = 1;   // Dialog Menu page number
integer  tipSplit       = 100; // % given to owner (default 100)
integer  totalDonations = 0;
integer  side_one       = 0;   // Face number for front of board
integer  side_two       = 5;   // Face number for back of board
integer  profile_key_prefix_length;
integer  profile_img_prefix_length;
integer  boardStatus;          // TRUE if board active, FALSE if board is disabled

integer  deflt_pay      = 250; // Default donation amount
list     quick_pay      = [100, 250, 500, 1000]; // quick pay buttons

float    maxTime        = 3600.0;
float    checkInterval  = 30.0;
float    maxDistance    = 15.0;

key      setupUser;
key      current;
key      lastRequestID;
key      owner;
key      tcher = NULL_KEY;

list     sides;
list     deftextures;
list     tipNames;
list     tipAmounts;

string   Name = "";
string   fallbackTexture = "Default_Texture"; // Name of your fallback texture
string   VERT_SPACE = "\n \n \n \n \n ";
string   profile_key_prefix = "<meta name=\"imageid\" content=\"";
string   profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
string   ownerName;
string   front_texture;
string   back_texture;
string   linksetValue;

// Linkset Data Keys
// Must match the definitions in DialogMenu.lsl
//
// Payment Avatar UUID linkset data key
string  PAY_UUID_LSD_KEY   = "payment_uuid";
// Total amount received linkset data key
string  TOTAL_AMT_LSD_KEY  = "total_donations";
// Front face texture linkset data key
string  FRONT_LSD_KEY      = "front_texture";
// Back face texture linkset data key
string  BACK_LSD_KEY       = "back_texture";
// Actions effect only this board or all boards
string  SOLO_LSD_KEY       = "solo";
// Group access to board menu or owner only
string  GROUP_LSD_KEY      = "group";

howtoPay() {
    llInstantMessage(tcher, "Please right-click the Donation Board and select 'Pay' to make a donation.");
}

stopDonation() {
    llSetClickAction(CLICK_ACTION_TOUCH);
    llSetPayPrice(PAY_HIDE, [PAY_HIDE ,PAY_HIDE, PAY_HIDE, PAY_HIDE]);
    boardStatus = FALSE;
}

startDonation() {
    llSetClickAction(CLICK_ACTION_PAY);
    llSetPayPrice(deflt_pay, quick_pay);
    boardStatus = TRUE;
}

stateDonation() {
    string prefix = "Truth & Beauty Donation Board version " + VERSION;
    string slurl = getBoardSlurl();
    string location = " at " + slurl;
    string msg;

    if (boardStatus) {
        msg = prefix + location + " is active and accepting donations";
    } else {
        msg = prefix + location + " is disabled and not accepting donations";
    }

    if (tcher == owner) {
        llOwnerSay(msg);
    } else {
        if (tcher) {
            llRegionSayTo(tcher, 0, msg);
        } else {
            llOwnerSay(msg);
        }
    }
}

updateHoverText() {
    string text = ownerName + "'s Donation Board\n";
    if (totalDonations > 0) {
        text += (string)totalDonations + " L$ donated so far!";
    } else {
        text += "Empty - Be the first to donate!";
    }
    text += VERT_SPACE;
    llSetText(text, <0.0, 1.0, 0.0>, 1.0); // Green hover text
}

string getBoardSlurl() {
    vector currentPos = llGetPos();
    string regionName = llGetRegionName();

    // Round coordinates to whole integers
    integer x = (integer)currentPos.x;
    integer y = (integer)currentPos.y;
    integer z = (integer)currentPos.z;
    string coords = (string)x + "/" + (string)y + "/" + (string)z;

    // Return the constructed Slurl, escape region name as it may have spaces
    return "https://maps.secondlife.com/secondlife/" + llEscapeURL(regionName) + "/" + coords;
}

GetDefaultTextures() {
    integer i;
    integer faces = llGetNumberOfSides();
    for (i = 0; i < faces; i++) {
        sides += i;
        deftextures += llGetTexture(i);
    }
}

UseFallbackTexture() {
    if (llGetInventoryType(fallbackTexture) == INVENTORY_TEXTURE) {
        llSetTexture(fallbackTexture, 3);
    } else {
        llOwnerSay("⚠️ Fallback texture not found in inventory: " + fallbackTexture);
        SetDefaultTextures();
    }
}

SetDefaultTextures() {
    integer i;
    integer faces = llGetNumberOfSides();
    for (i = 0; i < faces; i++) {
        llSetTexture(llList2String(deftextures, i), i);
    }
}

GetProfilePic(key id) {
    string url = "https://world.secondlife.com/resident/" + (string)id;
    lastRequestID = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
}

acceptDonation(key id, integer amount) {
    totalDonations += amount;
    string giverName = llKey2Name(id);

    // Thank the user publicly and privately
    llSay(0, "Thank you, " + giverName + ", for the generous donation of " + (string)amount + " L$!");
    llInstantMessage(id, "Your contribution of " + (string)amount + " L$ is greatly appreciated!");
        
    updateHoverText();

    integer Share = (amount * tipSplit) / 100;
    integer ownerShare = amount - Share;

    if (Share > 0) {
        llGiveMoney(current, Share);
        llInstantMessage(current, "You received a donation of L$" + (string)Share + " from " + giverName + "!");
    }

    if (ownerShare > 0) {
        llInstantMessage(owner, "You retained L$" + (string)ownerShare + " from a tip.");
    }
}

ReadyForDonations(key recKey) {
    current = recKey;
    Name = llKey2Name(current);
    LoggedIn = TRUE;

    // llSetText("Truth & Beauty Beach, " + Name + " \nDonations Welcome!", <0.5,1.0,0.5>, 1.0);
    llInstantMessage(current, "You are now logged in.");
    llSetTimerEvent(checkInterval);
    GetProfilePic(current);
}

list arrange(list l) {
    list outl = [];
    integer n = llGetListLength(l);
    do {
        if (n < 3) return outl + l;
        n = n - 3;
        outl = outl + llList2List(l, -3, -1);
        if (n == 0) return outl;
        l = llList2List(l, 0, -4);
    } while (TRUE);
    return [];
}

// Show the specific menu page
// Pass in the full menu list
ShowMenu(string msg, list fm) {
    integer list_length = llGetListLength(fm);
    if (list_length > 12) {
        integer totalPages = (list_length / 10) + (list_length % 10 != 0);

        // Safety check: bound page numbers
        if (pageNumber < 1) pageNumber = 1;
        if (pageNumber > totalPages) pageNumber = totalPages;

        integer nump = 12;
        if (pageNumber > 1) nump--;
        if (pageNumber < totalPages) nump--;

        // Calculate slice indices
        integer start = (pageNumber - 1) * nump;
        integer end = start + (nump -1);

        // Grab the 10 (or fewer) items for this page
        list displayList = llList2List(fm, start, end);

        // Add navigation buttons to the bottom of the list
        if (totalPages > 1) {
            if (pageNumber > 1) displayList += ["<<< Prev"];
            if (pageNumber < totalPages) displayList += ["Next >>>"];
        }

        // Send the dialog page
        llDialog(tcher, msg + " (Page " + (string)pageNumber + " of " +
                (string)totalPages + "):", arrange(displayList), dialogChannel);
    } else {
        // Send the dialog
        llDialog(tcher, msg, arrange(fm), dialogChannel);
    }
    llSetTimerEvent(120);   // If no response in time, return to previous state
}

displayMainMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");
    list main_menu = [];
    string menuMessage;

    menuMessage = "\nTruth & Beauty Donation Board " + VERSION;
    if (ALL) {
        menuMessage += "\nMenu actions effect ALL BOARDS IN REGION\n";
        menuMessage += "\nSOLO = Menu actions effect only this board";
    } else {
        menuMessage += "\nMenu actions effect ONLY THIS BOARD\n";
        menuMessage += "\nALL = Menu actions effect all boards in region";
    }
    menuMessage += "\nSETTINGS = Open the Board settings menu";
    menuMessage += "\nSIZE = Open the Board resize menu";
    menuMessage += "\nTEXTURE = Open the Board texture menu";
    main_menu = ["UP", "DOWN", "INFO"];
    if (ALL) {
        main_menu += ["SOLO"];
    } else {
        main_menu += ["ALL"];
    }
    main_menu += ["SETTINGS", "SIZE", "TEXTURE"];
    main_menu += ["EXIT"];
    ShowMenu(menuMessage, main_menu);
}

GetDatastoreValues() {
    //
    // Retrieve any configuration values stored in the linkset datastore
    //
    // Total amount received linkset data key
    linksetValue = llLinksetDataRead(TOTAL_AMT_LSD_KEY);
    if (linksetValue != "") {
        totalDonations = (integer)linksetValue;
    }
    // Payment Avatar UUID linkset data key
    linksetValue = llLinksetDataRead(PAY_UUID_LSD_KEY);
    if (linksetValue != "") {
        current = (key)linksetValue;
    }
    // Front face texture linkset data key
    linksetValue = llLinksetDataRead(FRONT_LSD_KEY);
    if (linksetValue != "") {
        front_texture = linksetValue;
    }
    // Back face texture linkset data key
    linksetValue = llLinksetDataRead(BACK_LSD_KEY);
    if (linksetValue != "") {
        back_texture = linksetValue;
    }
}

SetDatastoreValues() {
    //
    // Set all configuration values stored in the linkset datastore
    // Called from on_rez and when Save button is clicked
    //
    // Payment Avatar UUID linkset data key
    linksetDataWrite(owner, PAY_UUID_LSD_KEY, (string)current, "Payment receiving UUID");
    // Total amount received linkset data key
    linksetDataWrite(owner, TOTAL_AMT_LSD_KEY, (string)totalDonations, "Total amount donated");
    // Front face texture linkset data key
    linksetDataWrite(owner, FRONT_LSD_KEY, (string)front_texture, "Front Side Texture");
    // Back face texture linkset data key
    linksetDataWrite(owner, BACK_LSD_KEY, (string)back_texture, "Back Side Texture");
}

// Writes the provided key/value pair to the prim's linkset datastore
integer linksetDataWrite(key id, string lsdKey, string value, string cfg) {
    string val = llStringTrim(value, STRING_TRIM);
    integer returnCode = llLinksetDataWrite(lsdKey, val);
    if (returnCode == LINKSETDATA_OK) {
        if (id) {
            llRegionSayTo(id, 0, "[Donation Board] " + cfg + " saved.");
        }
    } else if (returnCode != LINKSETDATA_NOUPDATE) {
        if (id) {
            llRegionSayTo(id, 0, "[Donation Board] " + cfg + " save failed (code " + (string)returnCode + ").");
        }
    }
    return returnCode;
}

processMessage(integer chn, string msg) {
    string cmd = llToLower(msg);
    if (chn == listenChannel) {
        if (cmd == "donation stop") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Donation Stop");
            stopDonation();
        } else if (cmd == "donation start") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Donation Start");
            startDonation();
        } else if (cmd == "donation info") {
            // Send the message to other objects in region with same owner listening on this channel
            llRegionSay(objChannel, "Donation Info");
            stateDonation();
        }
    } else if (chn == objChannel) {
        // Don't resend the message if we are receiving a message on this channel
        if (cmd == "donation stop") {
            stopDonation();
        } else if (cmd == "donation start") {
            startDonation();
        } else if (cmd == "donation info") {
            stateDonation();
        }
    }
}

default {
    state_entry() {
        // Turn off touch to pay until we are ready to receive payments
        stopDonation();
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        GetDefaultTextures();
        owner     = llGetOwner();
        ownerName = llKey2Name(owner);
        tcher     = NULL_KEY;
        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);

        llRequestPermissions(owner, PERMISSION_DEBIT);
    }

    touch_start(integer num_detected) {
        tcher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                llResetTime(); // Starts tracking duration
            } else {
                howtoPay();
                tcher = NULL_KEY;
            }
        } else {
            if (tcher == owner) {
                llResetTime(); // Starts tracking duration
            } else {
                howtoPay();
                tcher = NULL_KEY;
            }
        }
    }

    touch_end(integer num_detected) {
        float holdTime = llGetTime();
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                if (holdTime >= 1.0) {
                    // Long press for dialog menu
                    // Handle dialog menu in its own state
                    state menu;
                } else {
                    startDonation();
                    state donate;
                }
            }
        } else {
            if (tcher == owner) {
                if (holdTime >= 1.0) {
                    // Long press for dialog menu
                    // Handle dialog menu in its own state
                    state menu;
                } else {
                    startDonation();
                    state donate;
                }
            }
        }
    }

    run_time_permissions(integer perms) {
        // If Debit permissions are granted, set up the pay price for this single-price vendor
        if (perms & PERMISSION_DEBIT) {
            llSetClickAction(CLICK_ACTION_PAY);
            updateHoverText();
            llOwnerSay("Donation Board is ready and online.");
            ReadyForDonations(owner);
        } else {
            llOwnerSay("⚠️ This script needs debit permissions to send money.");
        }
    }

    money(key id, integer amount) {
        acceptDonation(id, amount);
    }

    listen(integer channel, string name, key id, string message) {
        if (id != setupUser) return;

        integer input = (integer)message;
        if (input >= 0 && input <= 100) {
            tipSplit = input;
            llOwnerSay("✅ Donation split updated: " + (string)tipSplit + "% to owner.");
        } else {
            llOwnerSay("⚠️ Invalid input. Please enter a number between 0 and 100.");
        }
        llListenRemove(dialogHandle);
    }

    timer() {
        if (!LoggedIn) return;

        vector Pos = llList2Vector(llGetObjectDetails(current, [OBJECT_POS]), 0);
        vector jarPos = llGetPos();
        float distance = llVecDist(Pos, jarPos);

        if (distance > maxDistance) {
            llInstantMessage(current, "You were too far from the donation board and have been logged out.");
            LoggedIn = FALSE;
            current = NULL_KEY;
            Name = "";
            UseFallbackTexture();
            llSetTimerEvent(0.0);
        }
    }

    http_response(key req, integer status, list meta, string body) {
        if (req != lastRequestID) return;

        integer s1 = llSubStringIndex(body, profile_key_prefix);
        integer s1l = profile_key_prefix_length;

        if (s1 == -1) {
            s1 = llSubStringIndex(body, profile_img_prefix);
            s1l = profile_img_prefix_length;
        }

        if (s1 == -1) {
            UseFallbackTexture();
        } else {
            s1 += s1l;
            key UUID = llGetSubString(body, s1, s1 + 35);
            if (UUID == NULL_KEY) {
                UseFallbackTexture();
            } else {
                llSetTexture(UUID, 3);
            }
        }
    }

    changed(integer change) {
        // Check if the change event was caused by an owner change
        if (change & CHANGED_OWNER) {
            // Reset/wipe all key-value pairs in the linkset data store
            llLinksetDataReset();
            llResetScript();
        } else if (change & CHANGED_INVENTORY) {
            llResetScript();
        }
    }

    on_rez(integer num) {
        llResetScript();
        owner = llGetOwner();
        stopDonation();
        string slurl = getBoardSlurl();
        llOwnerSay("The Truth & Beauty Donation Board located at " + slurl + " is now active.");
        llOwnerSay("Activate the 'Start Donations', 'Stop Donations', and 'Donations Info' gestures in your inventory");
        llOwnerSay("Once activated, saying '/paystart' in public chat will enable all donation boards you own in this region");
        llOwnerSay("Saying '/paystop' will disable the donation boards");
        llOwnerSay("Saying '/payinfo' will report their status, version, and locations");
        llOwnerSay("Donation Board updates are free for life and will be available at:");
        llOwnerSay("    https://github.com/missyrestless/DonationBoard/releases");
        llOwnerSay("The latest Truth & Beauty Donation Board documentation can be found at:");
        llOwnerSay("    https://github.com/missyrestless/DonationBoard#readme");

        linksetValue = llLinksetDataRead(SOLO_LSD_KEY);
        if (linksetValue != "") {
            ALL = (integer)linksetValue;
        } else {
            ALL = TRUE;
        }
        linksetValue = llLinksetDataRead(GROUP_LSD_KEY);
        if (linksetValue != "") {
            GROUP = (integer)linksetValue;
        } else {
            GROUP = FALSE;
        }
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);
        SetDatastoreValues();
    }
}

state menu {
    state_entry() {
        displayMainMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "STOP") {
            if (ALL) {
                // Send the message to other boards in region with same owner listening on this channel
                llRegionSay(objChannel, "Donation Stop");
            }
            stopDonation();
            state default;
        } else if (message == "START") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Donation Start");
            }
            startDonation();
            state donate;
        } else if (message == "INFO") {
            if (ALL) {
                // Send the message to other objects in region with same owner listening on this channel
                llRegionSay(objChannel, "Donation Info");
            }
            stateDonation();
        } else if (message == "ALL") {
            ALL = TRUE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
        } else if (message == "SOLO") {
            ALL = FALSE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
        } else if (message == "GROUP") {
            if (id == owner) {
                if (ALL) {
                    // Send the message to other objects in region with same owner listening on this channel
                    llRegionSay(objChannel, "Group");
                }
                GROUP = TRUE;
                linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
            } else {
                if (id) llRegionSayTo(id, 0, "Only the owner can set the Boards to group access");
            }
        } else if (message == "OWNER") {
            if (id == owner) {
                if (ALL) {
                    // Send the message to other objects in region with same owner listening on this channel
                    llRegionSay(objChannel, "Owner");
                }
                GROUP = FALSE;
                linksetDataWrite(NULL_KEY, GROUP_LSD_KEY, (string)GROUP, "Group Access");
            } else {
                if (id) llRegionSayTo(id, 0, "Only the owner can set the Boards to owner only");
            }
        } else if (message == "EXIT") {
            // Return to the donation state
            state donate;
        }
        // Re-send the dialog to keep the menu open
        displayMainMenu();
    }

    timer() {
        // Return to the donation state
        state donate;
    }

    state_exit() {
        SetDatastoreValues();
        llSetTimerEvent(0);
    }
}

state donate {
    state_entry() {
        // Turn on touch to pay
        startDonation();
        tcher = NULL_KEY;
    }

    touch_start(integer num_detected) {
        tcher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (tcher == owner)) {
                state menu;
            }
        } else {
            if (tcher == owner) {
                state menu;
            }
        }
    }

    money(key id, integer amount) {
        acceptDonation(id, amount);
    }

    changed(integer change) {
        // Check if the change event was caused by an owner change
        if (change & CHANGED_OWNER) {
            // Reset/wipe all key-value pairs in the linkset data store
            llLinksetDataReset();
            llResetScript();
        } else if (change & CHANGED_INVENTORY) {
            llResetScript();
        }
    }
}
