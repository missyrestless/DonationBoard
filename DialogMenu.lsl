//                                               //
//  Provides dialog menus for the Truth & Beauty //
//  Donation Board. Messaging with the main      //
//  script is done with llMessageLinked()        //
///////////////////////////////////////////////////
//
////////////////////////////////////////////////////
// Copyright (c) 2026 Truth & Beauty Lab          //
// License: GPLv3                                 //
// All rights reserved.                           //
//                                                //
// Author: Missy Restless missyrestless@gmail.com //
////////////////////////////////////////////////////
//
// MODIFICATION HISTORY
// --------------------
// 10-Sep-2026 - Created by Missy Restless
// 15-Sep-2026 - Set parcel stream URL when user logs in/out
//
// VARIABLES
//
integer  boardStatus;           // TRUE if board active, FALSE if board is disabled
integer  dialogChannel;         // Dialog Menu channel and handle
integer  dialogHandle;
integer  inputChannel;          // Board name Input Box channel
integer  shareChannel;          // Share percent Input Box channel
integer  musicChannel;          // Stream URL Input Box channel
integer  pageNumber    = 1;
integer  first_amt     = -1;    // Pay button amounts
integer  second_amt    = -1;
integer  third_amt     = -1;
integer  fourth_amt    = -1;
integer  default_amt   = -1;
integer  side_one      = 0;     // Face number for front of board

integer  ALL           = TRUE;  // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP         = FALSE; // Set to TRUE to allow group members to manage, FALSE for owner only

integer  loggedIn;
integer  tipSplit      = 0;     // % shared
integer  twoSplit      = 80;    // default % shared to logged in user
integer  deflt_pay     = 250;   // Default donation amount
list     quick_pay     = [100, 250, 500, 1000]; // quick pay buttons

string  boardName;
string  front_texture;
string  linksetValue;
string  menuMessage;
string  streamURL      = "";
string  boardVersion   = "";
string  defaultVersion = "1.0.5";

// Linkset Data Keys
// Must match the definitions in DonationBoard.lsl
//
// Donation Board version linkset data key
string  VERSION_LSD_KEY   = "version";
// Payment Avatar UUID linkset data key
string  PAY_UUID_LSD_KEY   = "payment_uuid";
// Total amount received linkset data key
string  TOTAL_AMT_LSD_KEY  = "total_donations";
// Front face texture linkset data key
string  FRONT_LSD_KEY      = "front_texture";
// Actions effect only this board or all boards
string  SOLO_LSD_KEY       = "solo";
// Group access to board menu or owner only
string  GROUP_LSD_KEY      = "group";
// Original donation face texture
string  ORIGTEXT_LSD_KEY   = "orig_texture";
// Donation Board Name
string  BOARD_NAME_LSD_KEY = "board_name";
// Owner share percent
string  SHARE_LSD_KEY      = "share_percent";
// Default Pay dialog amount
string  DEF_PAY_LSD_KEY    = "default_payment";
// Pay dialog button amounts
string  PAY_AMTS_LSD_KEY   = "pay_amounts";
// Stream URL prefix, with avatar key appended
string  STREAM_URL_LSD_KEY = "";
string  STREAM_URL_PREFIX  = "url_";

// Link Messages to Donation Board
integer SND_LM_ALL         = 10;
integer SND_LM_SOLO        = 15;
integer SND_LM_DONATE      = 20;
integer SND_LM_IDLE        = 30;
integer SND_LM_INFO        = 40;
integer SND_LM_DATA_WRITE  = 45;
integer SND_LM_FRONT_TEXT  = 48;
integer SND_LM_GROUP       = 50;
integer SND_LM_TOTAL       = 55;
integer SND_LM_OBJMSG      = 60;
integer SND_LM_HOVER       = 70;
integer SND_LM_LOGIN       = 75;
integer SND_LM_PROFILE     = 80;
integer SND_LM_STREAM      = 88;
integer SND_LM_SHARE       = 90;
integer SND_LM_READ_AMTS   = 95;
integer SND_LM_DEBUG       = 99;
//
// Dialog Menu & listener for Webhook URL management
float   LISTEN_TTL      = 60.0;                
integer inputListen     = -1;
integer shareListen     = -1;
integer musicListen     = -1;
integer debug           = FALSE;

// Keys
key owner       = NULL_KEY;
key toucher     = NULL_KEY;

list getTextures() {
    list    texture_list = [];
    integer count = llGetInventoryNumber(INVENTORY_TEXTURE);
    string  textureName;

    // Populate list of inventory texture names
    integer i;
    for (i = 0; i < count; ++i) {
        textureName = llGetInventoryName(INVENTORY_TEXTURE, i);
        if ((textureName != "Sides") && (textureName != "Maintenance")) {
            texture_list += textureName;
        }
    }

    return texture_list;
}

// Removes elements of a list less than a minimum value
list trimList(list input_list, integer min_value) {
    integer i = llGetListLength(input_list) - 1;

    // Loop backwards through the list
    for (; i >= 0; --i) {
        // Check if the current item is less than or equal to the minimum
        if (llList2Integer(input_list, i) <= min_value) {
            // Delete the item from the list
            input_list = llDeleteSubList(input_list, i, i);
        }
    }

    return input_list;
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
showMenu(string msg, list fm) {
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
            if (pageNumber > 1) {
                displayList += ["<<< Prev"];
                if (debug) {
                    msg += "\nDEBUG Mode Enabled";
                } else {
                    msg += "\nDEBUG Mode Disabled";
                }
            }
            if (pageNumber < totalPages) displayList += ["Next >>>"];
        }

        // Send the dialog page
        llDialog(toucher, msg + " (Page " + (string)pageNumber + " of " +
                (string)totalPages + "):", arrange(displayList), dialogChannel);
    } else {
        // Send the dialog
        llDialog(toucher, msg, arrange(fm), dialogChannel);
    }
    llSetTimerEvent(120);   // If no response in time, return to previous state
}

displayMainMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", toucher, "");
    list main_menu = [];

    if (boardVersion == "") {
        // Make sure the Donation Board version is written
        linksetValue = llLinksetDataRead(VERSION_LSD_KEY);
        if (linksetValue != "") {
            boardVersion = linksetValue;
        } else {
            boardVersion = defaultVersion;
        }
    }
    menuMessage = "\nTruth & Beauty Donation Board " + boardVersion;
    if (ALL) {
        menuMessage += "\nMenu actions effect ALL BOARDS IN REGION\n";
        menuMessage += "\nSOLO = Menu actions effect only this board";
    } else {
        menuMessage += "\nMenu actions effect ONLY THIS BOARD\n";
        menuMessage += "\nALL = Menu actions effect all boards in region";
    }
    if (GROUP) {
        menuMessage += "\nOWNER = Owner only access";
    } else {
        menuMessage += "\nGROUP = Allow group members to manage";
    }
    menuMessage += "\nAMOUNTS = pay dialog suggested amounts";
    menuMessage += "\nHOVER TXT = Set the Board hover text";
    if (toucher == owner) {
        menuMessage += "\nCLEAR = Reset and clear the datastore";
        menuMessage += "\nSHARE = Set the Board donation share percent";
    }
    menuMessage += "\nSTREAM = Set the parcel music stream URL";
    menuMessage += "\nTEXTURE = Open the Board texture menu";
    menuMessage += "\nTOTAL = Toggle display of total donations";
    if (boardStatus) {
        main_menu = ["STOP", "INFO"];
        menuMessage += "\n\nThis Board is active and accepting donations";
    } else {
        main_menu = ["START", "INFO"];
        menuMessage += "\n\nThis Board is disabled and not accepting donations";
    }
    if (ALL) {
        main_menu += ["SOLO"];
    } else {
        main_menu += ["ALL"];
    }
    if (GROUP) {
        main_menu += ["OWNER"];
    } else {
        main_menu += ["GROUP"];
    }
    if (loggedIn) {
        main_menu += ["LOGOUT"];
    } else {
        main_menu += ["LOGIN"];
    }
    if (toucher == owner) {
        main_menu += ["AMOUNTS", "HOVER TXT", "STREAM", "TEXTURE", "TOTAL", "EXIT", "CLEAR", "DEBUG", "SHARE", "EXIT"];
    } else {
        main_menu += ["AMOUNTS", "HOVER TXT", "STREAM", "TEXTURE", "TOTAL", "EXIT"];
    }
    showMenu(menuMessage, main_menu);
}

displayTextMenu() {
    list face_menu = [];
    list text_menu = [];

    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", toucher, "");

    menuMessage = "\nTruth & Beauty Donation Board Texture Menu";

    // Populate the inventory textures menu entries
    if (ALL) {
        menuMessage += "\nTexture ALL BOARDS IN REGION\n";
        menuMessage += "\nSOLO = Apply selected texture to only this board";
    } else {
        menuMessage += "\nTexture THIS BOARD ONLY\n";
        menuMessage += "\nALL = Apply selected texture to all boards";
    }
    menuMessage += "\nFLIP HORIZ = Flip texture horizontally";
    menuMessage += "\nFLIP VERT  = Flip texture vertically\n";
    menuMessage += "\nCurrent texture: " + llGetTexture(side_one) + "\n";
    face_menu = ["BACK", "RESTORE", "EXIT"];
    if (ALL) {
        face_menu += ["SOLO"];
    } else {
        face_menu += ["ALL"];
    }
    face_menu += ["FLIP HORIZ", "FLIP VERT", "PROFILE"];
    text_menu = getTextures();
    if (text_menu) {
        menuMessage += "\nSelect the texture to use on face " + (string)side_one + "\n";
        face_menu += text_menu;
        face_menu += ["BACK", "RESTORE", "EXIT"];
    } else {
        menuMessage += "\nNO TEXTURES FOUND\n";
    }
    showMenu(menuMessage, face_menu);
}

displayAmtsMenu() {
    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", toucher, "");
    list amts_menu = [];

    menuMessage = "\nTruth & Beauty Donation Board " + boardVersion;
    menuMessage += "\nCurrent Pay Buttons: " + llDumpList2String(quick_pay, ", ");
    menuMessage += "\nCurrent Default Amount: " + (string)deflt_pay;
    menuMessage += "\nSet Donation Amounts on THIS BOARD ONLY\n";
    if (first_amt == -1) {
        menuMessage += "\nSelect first (lowest) donation amount\n";
        amts_menu = ["10", "20", "50", "100", "250", "500", "750", "SKIP"];
    } else if (second_amt == -1) {
        menuMessage += "\nSelect second donation amount\n";
        amts_menu = [trimList(["50", "100", "250", "300", "500", "750", "1000"], first_amt)];
        amts_menu += ["SKIP"];
    } else if (third_amt == -1) {
        menuMessage += "\nSelect third donation amount\n";
        amts_menu = [trimList(["150", "250", "300", "500", "750", "1000", "1500"], second_amt)];
        amts_menu += ["SKIP"];
    } else if (fourth_amt == -1) {
        menuMessage += "\nSelect fourth donation amount\n";
        amts_menu = [trimList(["200", "250", "500", "750", "1000", "1500", "2000"], third_amt)];
        amts_menu += ["SKIP"];
    } else if (default_amt == -1) {
        menuMessage += "\nSelect default donation amount\n";
        amts_menu = [llList2String(quick_pay, 0), llList2String(quick_pay, 1), llList2String(quick_pay, 2), llList2String(quick_pay, 3), "SKIP"];
    } else {
        menuMessage += "\nClick DONE to save these pay buttons values\n";
        menuMessage += "\nClick a BUTTON button to change that button's value\n";
        amts_menu += ["BUTTON 1", "BUTTON 2", "BUTTON 3", "BUTTON 4", "DEFAULT"];
    }
    amts_menu += ["DONE", "EXIT"];
    showMenu(menuMessage, amts_menu);
}

// Writes the provided key/value pair to the prim's linkset datastore
integer linksetDataWrite(string lsdKey, string value, string cfg) {
    string val = llStringTrim(value, STRING_TRIM);
    integer returnCode = llLinksetDataWrite(lsdKey, val);
    if (returnCode == LINKSETDATA_OK) {
        if (owner) {
            if (debug) llRegionSayTo(owner, 0, "[Donation Board] " + cfg + " saved.");
        }
    } else if (returnCode != LINKSETDATA_NOUPDATE) {
        if (owner) {
            if (debug) llRegionSayTo(owner, 0, "[Donation Board] " + cfg + " save failed (code " + (string)returnCode + ").");
        }
    }

    return returnCode;
}

string lnk_msg(integer sender, integer num, string message, key id) {
    // Receive from Donation Board
    integer RCV_LM_MENU        = 100;
    integer RCV_LM_GROUP       = 150;
    integer RCV_LM_LOGIN       = 175;
    integer RCV_LM_STATUS_ON   = 200;
    integer RCV_LM_STATUS_OFF  = 210;
    integer RCV_LM_SHARE       = 250;
    integer RCV_LM_STREAM      = 300;

    string ret_state = "";

    if (num == RCV_LM_MENU) {
        toucher = id;
        ret_state = "menu";
    } else if (num == RCV_LM_GROUP) {
        if (message == "Group") {
            GROUP = TRUE;
        } else if (message == "Owner") {
            GROUP = FALSE;
        }
    } else if (num == RCV_LM_LOGIN) {
        if ((integer)message) {
            loggedIn = TRUE;
            STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)id;
        } else {
            loggedIn = FALSE;
            STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)owner;
        }
        streamURL = llLinksetDataRead(STREAM_URL_LSD_KEY);
        if (streamURL == "") {
            getStreamURL(id);
        }
    } else if (num == RCV_LM_STREAM) {
        STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)id;
        streamURL = message;
    } else if (num == RCV_LM_SHARE) {
        string split = llJsonGetValue(message, ["split"]);
        tipSplit = (integer)split;
        string share = llJsonGetValue(message, ["share"]);
        twoSplit = (integer)share;
    } else if (num == RCV_LM_STATUS_ON) {
        llSetClickAction(CLICK_ACTION_PAY);
        llSetPayPrice(deflt_pay, quick_pay);
        boardStatus = TRUE;
    } else if (num == RCV_LM_STATUS_OFF) {
        llSetClickAction(CLICK_ACTION_TOUCH);
        // llSetPayPrice(PAY_HIDE, [PAY_HIDE ,PAY_HIDE, PAY_HIDE, PAY_HIDE]);
        llSetPayPrice(deflt_pay, quick_pay);
        boardStatus = FALSE;
    }

    return ret_state;
}

getStreamURL(key id) {
    if (musicListen != -1) llListenRemove(musicListen);
    musicListen = llListen(musicChannel, "", id, "");
    llSetTimerEvent(LISTEN_TTL);
    llTextBox(id, "\nEnter the parcel music URL to use (currently " + streamURL + ")", musicChannel);
}

processInput(string message) {
    boardName = llStringTrim(message, STRING_TRIM);
    linksetDataWrite(BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");
    llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");

    if (inputListen != -1) {
        llListenRemove(inputListen);
        inputListen = -1;
    }
}

processStream(string message, key id) {
    streamURL = message;
    if (loggedIn) {
        STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)id;
    } else {
        STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)owner;
    }
    linksetDataWrite(STREAM_URL_LSD_KEY, message, "Parcel Stream URL");

    llMessageLinked(LINK_THIS, SND_LM_STREAM, message, id);

    if (musicListen != -1) {
        llListenRemove(musicListen);
        musicListen = -1;
    }
}

processShare(string message) {
    message = llReplaceSubString(message, "%", "", 0);
    twoSplit = (integer)message;
    if (loggedIn) {
        tipSplit = twoSplit;
    } else {
        tipSplit = 0;
    }
    linksetDataWrite(SHARE_LSD_KEY, message, "Owner donation percent");

    llMessageLinked(LINK_THIS, SND_LM_SHARE, message, "");

    if (shareListen != -1) {
        llListenRemove(shareListen);
        shareListen = -1;
    }
}

default {
    state_entry() {
        owner         = llGetOwner();

        // Compute a negative communications channel based on prim UUID
        dialogChannel = 0x80000000 | (integer) ( "0x" + (string) llGetKey() );
        inputChannel  = (integer)(llFrand(-1000000000.0) - 1000000000.0);
        shareChannel  = (integer)(llFrand(-1000000000.0) - 1000000000.0);
        musicChannel  = (integer)(llFrand(-1000000000.0) - 1000000000.0);
    }

    link_message(integer sender, integer num, string message, key id) {
        if (lnk_msg(sender, num, message, id) == "menu") {
            state menu;
        }
    }

    changed(integer change) {
         if (change & (CHANGED_OWNER | CHANGED_INVENTORY)) {
             llResetScript();
         }
    }

    on_rez(integer param) {
        llResetScript();
    }
}

state menu {
    state_entry() {
        displayMainMenu();
    }

    link_message(integer sender, integer num, string message, key id) {
        if (lnk_msg(sender, num, message, id) == "menu") {
            state menu;
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == inputChannel) {
            processInput(message);
        } else if (channel == musicChannel) {
            processStream(message, id);
        } else if (channel == shareChannel) {
            processShare(message);
        } else if (channel == dialogChannel) {
            if (message == "STOP") {
                llMessageLinked(LINK_THIS, SND_LM_IDLE, "Donation Stop", owner);
                boardStatus = FALSE;
            } else if (message == "START") {
                llMessageLinked(LINK_THIS, SND_LM_DONATE, "Donation Start", id);
                boardStatus = TRUE;
            } else if (message == "AMOUNTS") {
                state amts;
            } else if (message == "INFO") {
                llMessageLinked(LINK_THIS, SND_LM_INFO, "Donation Info", id);
            } else if (message == "ALL") {
                ALL = TRUE;
                linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
                llMessageLinked(LINK_THIS, SND_LM_ALL, "", owner);
            } else if (message == "SOLO") {
                ALL = FALSE;
                linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
                llMessageLinked(LINK_THIS, SND_LM_SOLO, "", owner);
            } else if (message == "GROUP") {
                if (id == owner) {
                    GROUP = TRUE;
                    llMessageLinked(LINK_THIS, SND_LM_GROUP, "Group", id);
                    linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group Access");
                } else {
                    if (id) llRegionSayTo(id, 0, "Only the owner can set the Boards to group access");
                }
            } else if (message == "OWNER") {
                if (id == owner) {
                    GROUP = FALSE;
                    llMessageLinked(LINK_THIS, SND_LM_GROUP, "Owner", id);
                    linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group Access");
                } else {
                    if (id) llRegionSayTo(id, 0, "Only the owner can set the Boards to owner only");
                }
            } else if (message == "CLEAR") {
                state confirm;
            } else if (message == "DEBUG") {
                debug = !debug;
                llMessageLinked(LINK_THIS, SND_LM_DEBUG, (string)debug, "");
            } else if ((message == "LOGIN")|| (message == "LOGOUT")) {
                llMessageLinked(LINK_THIS, SND_LM_LOGIN, (string)loggedIn, id);
                loggedIn = !loggedIn;
                if (loggedIn) {
                    STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)id;
                    streamURL = llLinksetDataRead(STREAM_URL_LSD_KEY);
                    if (streamURL == "") {
                        getStreamURL(id);
                    } else {
                        llMessageLinked(LINK_THIS, SND_LM_STREAM, streamURL, id);
                    }
                } else {
                    STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)owner;
                }
            } else if (message == "HOVER TXT") {
                if (inputListen != -1) llListenRemove(inputListen);
                inputListen = llListen(inputChannel, "", id, "");
                llSetTimerEvent(LISTEN_TTL);
                llTextBox(id, "\nEnter the Donation Board hover text into the box", inputChannel);
                return; // Exit the listen event
            } else if (message == "STREAM") {
                getStreamURL(id);
                return; // Exit the listen event
            } else if (message == "SHARE") {
                if (shareListen != -1) llListenRemove(shareListen);
                shareListen = llListen(shareChannel, "", id, "");
                llSetTimerEvent(LISTEN_TTL);
                llTextBox(id, "\nEnter the percent to share with a logged in user (currently " + (string)twoSplit + "%)", shareChannel);
                return; // Exit the listen event
            } else if (message == "TEXTURE") {
                state text;
            } else if (message == "TOTAL") {
                llMessageLinked(LINK_THIS, SND_LM_TOTAL, "", "");
            } else if (message == "<<< Prev") {
                pageNumber--;
            } else if (message == "Next >>>") {
                pageNumber++;
            } else if (message == "EXIT") {
                state default;
            }
        }
        // Re-send the dialog to keep the menu open
        displayMainMenu();
    }

    timer() {
        if (inputListen != -1) { llListenRemove(inputListen); inputListen = -1; }
        if (musicListen != -1) { llListenRemove(musicListen); musicListen = -1; }
        if (shareListen != -1) { llListenRemove(shareListen); shareListen = -1; }
        llSetTimerEvent(0.0);
        state default;
    }

    state_exit() {
        llMessageLinked(LINK_THIS, SND_LM_DATA_WRITE, "", "");
        llSetTimerEvent(0);
    }
}

state text {
    state_entry() {
        displayTextMenu();
    }

    link_message(integer sender, integer num, string message, key id) {
        if (lnk_msg(sender, num, message, id) == "menu") {
            state menu;
        }
    }

    listen(integer channel, string name, key id, string message) {
        vector scale_vector;

        if (channel == inputChannel) {
            processInput(message);
        } else if (channel == musicChannel) {
            processStream(message, id);
        } else if (channel == shareChannel) {
            processShare(message);
        } else if (channel == dialogChannel) {
            if (message == "ALL") {
                ALL = TRUE;
                linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
                llMessageLinked(LINK_THIS, SND_LM_ALL, "", owner);
            } else if (message == "SOLO") {
                ALL = FALSE;
                linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
                llMessageLinked(LINK_THIS, SND_LM_SOLO, "", owner);
            } else if (message == "FLIP HORIZ") {
                // Flips the texture horizontally on selected face, keeping vertical scale
                scale_vector = llGetTextureScale(side_one);
                llScaleTexture(-(scale_vector.x), scale_vector.y, side_one);
            } else if (message == "FLIP VERT") {
                // Flips the texture vertically on selected face, keeping horizontal scale
                scale_vector = llGetTextureScale(side_one);
                llScaleTexture(scale_vector.x, -(scale_vector.y), side_one);
            } else if (message == "PROFILE") {
                llMessageLinked(LINK_THIS, SND_LM_PROFILE, "", owner);
            } else if (message == "RESTORE") {
                linksetValue = llLinksetDataRead(ORIGTEXT_LSD_KEY);
                if (linksetValue != "") {
                    llSetTexture(linksetValue, side_one);
                    front_texture = linksetValue;
                    llMessageLinked(LINK_THIS, SND_LM_FRONT_TEXT, front_texture, "");
                } else {
                    llSetTexture(front_texture, side_one);
                    linksetDataWrite(ORIGTEXT_LSD_KEY, front_texture, "Original Board Textures");
                }
            } else if (message == "BACK") {
                state menu;
            // Handle pagination for multi page menus
            } else if (message == "<<< Prev") {
                pageNumber--;
            } else if (message == "Next >>>") {
                pageNumber++;
            } else if (message == "EXIT") {
                state default;
            } else {
                if (llGetInventoryType(message) == INVENTORY_TEXTURE) {
                    llSetTexture(message, side_one);
                    front_texture = message;
                    llMessageLinked(LINK_THIS, SND_LM_FRONT_TEXT, message, "");
                    // Send the texture message to other boards listening on the object channel
                    llMessageLinked(LINK_THIS, SND_LM_OBJMSG, llList2Json(JSON_OBJECT, ["texture", message, "face", (string)side_one]), owner);
                } else {
                    if (debug) llRegionSayTo(toucher, 0, "The texture is missing or not a texture: " + message);
                }
            }
        }
        // Re-send the dialog to keep the menu open
        displayTextMenu();
    }

    timer() {
        llSetTimerEvent(0.0);
        state default;
    }

    state_exit() {
        llMessageLinked(LINK_THIS, SND_LM_DATA_WRITE, "", "");
        llSetTimerEvent(0);
    }
}

state amts {
    state_entry() {
        first_amt      = -1;
        second_amt     = -1;
        third_amt      = -1;
        fourth_amt     = -1;
        default_amt    = -1;
        displayAmtsMenu();
    }

    link_message(integer sender, integer num, string message, key id) {
        if (lnk_msg(sender, num, message, id) == "menu") {
            state menu;
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == inputChannel) {
            processInput(message);
        } else if (channel == musicChannel) {
            processStream(message, id);
        } else if (channel == shareChannel) {
            processShare(message);
        } else if (channel == dialogChannel) {
            if (message == "DONE") {
                linksetDataWrite(PAY_AMTS_LSD_KEY, llList2CSV(quick_pay), "Pay Buttons Amounts");
                linksetDataWrite(DEF_PAY_LSD_KEY, (string)deflt_pay, "Default Pay Amount");
                llSetPayPrice(deflt_pay, quick_pay);
                llMessageLinked(LINK_THIS, SND_LM_READ_AMTS, "", "");
                state default;
            } else if (message == "BUTTON 1") {
                first_amt = -1;
            } else if (message == "BUTTON 2") {
                second_amt = -1;
            } else if (message == "BUTTON 3") {
                third_amt = -1;
            } else if (message == "BUTTON 4") {
                fourth_amt = -1;
            } else if (message == "DEFAULT") {
                default_amt = -1;
            } else if (message == "OWNER") {
                if (id == owner) {
                    GROUP = FALSE;
                    llMessageLinked(LINK_THIS, SND_LM_GROUP, "Owner", id);
                    linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group Access");
                } else {
                    if (id) llRegionSayTo(id, 0, "Only the owner can set the Boards to owner only");
                }
            } else if (message == "HOVER TXT") {
                if (inputListen != -1) llListenRemove(inputListen);
                inputListen = llListen(inputChannel, "", id, "");
                llSetTimerEvent(LISTEN_TTL);
                llTextBox(id, "\nEnter the Donation Board hover text into the box)", inputChannel);
                return; // Exit the listen event
            } else if (message == "TEXTURE") {
                state text;
            } else if (message == "EXIT") {
                state default;
            } else {
                if (first_amt == -1) {
                    if (message == "SKIP") {
                        first_amt = llList2Integer(quick_pay, 0);
                    } else {
                        quick_pay = llListReplaceList(quick_pay, [message], 0, 0);
                        first_amt = llList2Integer(quick_pay, 0);
                    }
                } else if (second_amt == -1) {
                    if (message == "SKIP") {
                        second_amt = llList2Integer(quick_pay, 1);
                    } else {
                        quick_pay = llListReplaceList(quick_pay, [message], 1, 1);
                        second_amt = llList2Integer(quick_pay, 1);
                    }
                } else if (third_amt == -1) {
                    if (message == "SKIP") {
                        third_amt = llList2Integer(quick_pay, 2);
                    } else {
                        quick_pay = llListReplaceList(quick_pay, [message], 2, 2);
                        third_amt = llList2Integer(quick_pay, 2);
                    }
                } else if (fourth_amt == -1) {
                    if (message == "SKIP") {
                        fourth_amt = llList2Integer(quick_pay, 3);
                    } else {
                        quick_pay = llListReplaceList(quick_pay, [message], 3, 3);
                        fourth_amt = llList2Integer(quick_pay, 3);
                    }
                } else if (default_amt == -1) {
                    if (message == "SKIP") {
                        default_amt = deflt_pay;
                    } else {
                        deflt_pay = (integer)message;
                        default_amt = deflt_pay;
                    }
                }
                linksetDataWrite(PAY_AMTS_LSD_KEY, llList2CSV(quick_pay), "Pay Buttons Amounts");
                linksetDataWrite(DEF_PAY_LSD_KEY, (string)deflt_pay, "Default Pay Amount");
            }
        }
        // Re-send the dialog to keep the menu open
        displayAmtsMenu();
    }

    timer() {
        if (inputListen != -1) { llListenRemove(inputListen); inputListen = -1; }
        if (musicListen != -1) { llListenRemove(musicListen); musicListen = -1; }
        if (shareListen != -1) { llListenRemove(shareListen); shareListen = -1; }
        llSetTimerEvent(0.0);
        state default;
    }

    state_exit() {
        llMessageLinked(LINK_THIS, SND_LM_DATA_WRITE, "", "");
        llSetTimerEvent(0);
    }
}

state confirm {
    state_entry() {
        llListenRemove(inputListen);
        inputListen = llListen(inputChannel, "", owner, "");
        llSetTimerEvent(LISTEN_TTL);

        string msg = "This will clear all customized settings from storage";
        msg += "\nAre you sure you want to proceed?";
        llDialog(owner, msg, ["YES", "NO"], inputChannel);
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == inputChannel) {
            llListenRemove(inputListen);
            inputListen = -1;
            if (message == "YES") {
                llLinksetDataReset();
                llResetScript();
            } else if (message == "NO") {
                if (debug) llOwnerSay("Clear linkset storage action cancelled.");
            }
            state menu;
        } else if (channel == musicChannel) {
            processStream(message, id);
        } else if (channel == shareChannel) {
            processShare(message);
        }
    }

    timer() {
        llListenRemove(inputListen);
        inputListen = -1;
        llSetTimerEvent(0.0);
        state menu;
    }
}
