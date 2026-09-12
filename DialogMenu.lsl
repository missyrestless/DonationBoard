//// Truth & Beauty Donation Board Dialog Menu ////
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
//
// VARIABLES
//
integer  boardStatus;           // TRUE if board active, FALSE if board is disabled
integer  dialogChannel;         // Dialog Menu channel and handle
integer  dialogHandle;
integer  inputChannel;          // Input Box channel
integer  pageNumber    = 1;
integer  first_amt     = -1;    // Pay button amounts
integer  second_amt    = -1;
integer  third_amt     = -1;
integer  fourth_amt    = -1;
integer  default_amt   = -1;
integer  side_one      = 0;     // Face number for front of board
integer  side_two      = 5;     // Face number for back of board
integer  inDialogMenu  = FALSE;
integer  particles     = TRUE;
integer  ALL           = TRUE;  // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP         = FALSE; // Set to TRUE to allow group members to manage, FALSE for owner only

integer  deflt_pay     = 250;   // Default donation amount
list     quick_pay     = [100, 250, 500, 1000]; // quick pay buttons

string  boardName;
string  boardVersion;
string  front_texture;
string  back_texture;
string  linksetValue;
string  menuMessage;

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
// Back face texture linkset data key
string  BACK_LSD_KEY       = "back_texture";
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

// Receive from Donation Board
integer RCV_LM_MENU        = 100;
integer RCV_LM_GROUP       = 150;
integer RCV_LM_STATUS_ON   = 200;
integer RCV_LM_STATUS_OFF  = 210;

// Link Messages to Donation Board
integer SND_LM_ALL         = 10;
integer SND_LM_SOLO        = 15;
integer SND_LM_DONATE      = 20;
integer SND_LM_IDLE        = 30;
integer SND_LM_INFO        = 40;
integer SND_LM_GROUP       = 50;
integer SND_LM_OBJMSG      = 60;
integer SND_LM_HOVER       = 70;
integer SND_LM_PROFILE     = 80;
//
// Dialog Menu & listener for Webhook URL management
float   LISTEN_TTL      = 60.0;                
integer inputListen     = -1;

// Frame style and textures
string  profilePic     = "";
string  ProfileTexture = "";

// Should online status messages be restricted to owner
integer ownerOnly = TRUE;
string pageMenuName;

// Keys
key owner       = NULL_KEY;
key toucher     = NULL_KEY;

howtoPay() {
    llInstantMessage(toucher, "Please right-click the Donation Board and select 'Pay' to make a donation.");
}

list getTextures() {
    list texture_list = [];
    integer count = llGetInventoryNumber(INVENTORY_TEXTURE);

    // Populate list of inventory texture names
    integer i;
    for (i = 0; i < count; ++i) {
        texture_list += llGetInventoryName(INVENTORY_TEXTURE, i);
    }
    return texture_list;
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
            if (pageNumber > 1) displayList += ["<<< Prev"];
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
    menuMessage += "\nAMOUNTS = Set the donation amounts for the pay dialog";
    menuMessage += "\nNAME = Set the Board name hover text";
    menuMessage += "\nTEXTURE = Open the Board texture menu";
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
    main_menu += ["AMOUNTS", "NAME", "TEXTURE", "EXIT"];
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
        amts_menu += ["10", "20", "50", "100", "250", "500", "750", "SKIP"];
    } else if (second_amt == -1) {
        menuMessage += "\nSelect second donation amount\n";
        amts_menu += ["50", "100", "250", "300", "500", "750", "1000", "SKIP"];
    } else if (third_amt == -1) {
        menuMessage += "\nSelect third donation amount\n";
        amts_menu += ["150", "250", "300", "500", "750", "1000", "1500", "SKIP"];
    } else if (fourth_amt == -1) {
        menuMessage += "\nSelect fourth donation amount\n";
        amts_menu += ["150", "200", "250", "500", "750", "1000", "1500", "SKIP"];
    } else if (default_amt == -1) {
        menuMessage += "\nSelect default donation amount\n";
        amts_menu += [llList2String(quick_pay, 0), llList2String(quick_pay, 1), llList2String(quick_pay, 2), llList2String(quick_pay, 3), "SKIP"];
    } else {
        menuMessage += "\nClick DONE to save these pay buttons values\n";
        menuMessage += "\nClick a BUTTON button to change that button's value\n";
        amts_menu += ["BUTTON 1", "BUTTON 2", "BUTTON 3", "BUTTON 4", "DEFAULT"];
    }
    amts_menu += ["DONE", "EXIT"];
    showMenu(menuMessage, amts_menu);
}

getDatastoreValues() {
    //
    // Retrieve any configuration values stored in the linkset datastore
    //
    // Donation Board Version
    linksetValue = llLinksetDataRead(VERSION_LSD_KEY);
    if (linksetValue != "") {
        boardVersion = linksetValue;
    } else {
        boardVersion = "Unknown";
    }
    // Donation Board Name
    linksetValue = llLinksetDataRead(BOARD_NAME_LSD_KEY);
    if (linksetValue != "") {
        boardName = linksetValue;
    } else {
        boardName = llKey2Name(owner);
    }
    // Front face texture linkset data key
    linksetValue = llLinksetDataRead(FRONT_LSD_KEY);
    if (linksetValue != "") {
        front_texture = linksetValue;
    } else {
        front_texture = llGetTexture(side_one);
    }
    // Back face texture linkset data key
    linksetValue = llLinksetDataRead(BACK_LSD_KEY);
    if (linksetValue != "") {
        back_texture = linksetValue;
    } else {
        back_texture = llGetTexture(side_two);
    }
    // Solo or All linkset data key
    linksetValue = llLinksetDataRead(SOLO_LSD_KEY);
    if (linksetValue != "") {
        ALL = (integer)linksetValue;
    }
    // Group or Owner access linkset data key
    linksetValue = llLinksetDataRead(GROUP_LSD_KEY);
    if (linksetValue != "") {
        GROUP = (integer)linksetValue;
    }
    // Default Pay dialog amount
    linksetValue = llLinksetDataRead(DEF_PAY_LSD_KEY);
    if (linksetValue != "") {
        deflt_pay = (integer)linksetValue;
    }
    // Pay dialog button amounts
    linksetValue = llLinksetDataRead(PAY_AMTS_LSD_KEY);
    if (linksetValue != "") {
        quick_pay = llCSV2List(linksetValue);
    }
}

setDatastoreValues() {
    //
    // Set all configuration values stored in the linkset datastore
    //
    // Donation Board Name
    linksetDataWrite(BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");
    // Front face texture linkset data key
    linksetDataWrite(FRONT_LSD_KEY, (string)front_texture, "Front Side Texture");
    // Back face texture linkset data key
    linksetDataWrite(BACK_LSD_KEY, (string)back_texture, "Back Side Texture");
    // Solo or All linkset data key
    linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "Solo or All Boards");
    // Group or Owner access linkset data key
    linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group or Owner access");
    // Default Pay dialog amount
    linksetDataWrite(DEF_PAY_LSD_KEY, (string)deflt_pay, "Default Pay Amount");
    // Pay dialog button amounts
    linksetDataWrite(PAY_AMTS_LSD_KEY, llList2CSV(quick_pay), "Pay Buttons Amounts");
}

// Writes the provided key/value pair to the prim's linkset datastore
integer linksetDataWrite(string lsdKey, string value, string cfg) {
    string val = llStringTrim(value, STRING_TRIM);
    integer returnCode = llLinksetDataWrite(lsdKey, val);
    if (returnCode == LINKSETDATA_OK) {
        if (owner) {
            llRegionSayTo(owner, 0, "[Donation Board] " + cfg + " saved.");
        }
    } else if (returnCode != LINKSETDATA_NOUPDATE) {
        if (owner) {
            llRegionSayTo(owner, 0, "[Donation Board] " + cfg + " save failed (code " + (string)returnCode + ").");
        }
    }
    return returnCode;
}

particlesOff() {
    llParticleSystem([]);
}

bling() {
    particlesOff();
    llParticleSystem([
        PSYS_PART_FLAGS, (0
                           | PSYS_PART_INTERP_COLOR_MASK
                           | PSYS_PART_EMISSIVE_MASK
                           | PSYS_PART_INTERP_SCALE_MASK
                           | PSYS_PART_FOLLOW_VELOCITY_MASK
                           | PSYS_PART_WIND_MASK
                         ),
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,

        // Color Parameters
        PSYS_PART_START_COLOR,     <1.0, 0.5, 0.0>, // Bright Orange
        PSYS_PART_END_COLOR,       <0.0, 0.0, 1.0>, // Fades to Blue

        // Transparency
        PSYS_PART_START_ALPHA,     1.0,
        PSYS_PART_END_ALPHA,       0.2,

        // Size
        PSYS_PART_START_SCALE,     <0.5, 0.5, 0.0>,
        PSYS_PART_END_SCALE,       <2.0, 2.0, 0.0>,

        // Timing & Speed
        PSYS_PART_MAX_AGE,         3.0,
        PSYS_SRC_BURST_RATE,       0.5,
        PSYS_SRC_BURST_PART_COUNT, 2,
        PSYS_SRC_BURST_SPEED_MIN,  1.0,
        PSYS_SRC_BURST_SPEED_MAX,  3.0
    ]);
}

hearts() {
    particlesOff();
    llParticleSystem([
        PSYS_SRC_TEXTURE, "5b3f3df0-b20b-5dc4-b49e-377c5805a0e3",
        PSYS_PART_START_SCALE,     <0.1, 0.1, FALSE>,
        PSYS_PART_END_SCALE,       <0.4, 0.4, FALSE>,
        PSYS_PART_START_ALPHA,     1.0,
        PSYS_PART_END_ALPHA,       0.5,

        PSYS_SRC_BURST_PART_COUNT, 2,
        PSYS_SRC_BURST_RATE,       0.5,
        PSYS_PART_MAX_AGE,         2.0,
        PSYS_SRC_MAX_AGE,          0.0,

        PSYS_SRC_PATTERN,          2,
        PSYS_SRC_BURST_SPEED_MIN,  0.5,
        PSYS_SRC_BURST_SPEED_MAX,  2.0,
        PSYS_SRC_BURST_RADIUS,     0.000000,

        PSYS_SRC_ANGLE_BEGIN,      0.05*PI,
        PSYS_SRC_ANGLE_END,        0.05*PI,
        PSYS_SRC_OMEGA,            <0.0, 0.0, 0.0>,

        PSYS_SRC_ACCEL,            <0.0, 0.0, 0.0>,
        PSYS_SRC_TARGET_KEY,       (key)"",

        PSYS_PART_FLAGS, ( 0
                             | PSYS_PART_INTERP_COLOR_MASK
                             | PSYS_PART_INTERP_SCALE_MASK
                             | PSYS_PART_EMISSIVE_MASK
                             | PSYS_PART_FOLLOW_VELOCITY_MASK
                             | PSYS_PART_WIND_MASK
                         )
    ]);
}

sparkle() {
    particlesOff();
    llParticleSystem([
        PSYS_PART_START_SCALE,     <0.00, 0.20, 0>,
        PSYS_PART_END_SCALE,       <0.40, 0.00, 0>,
        PSYS_PART_START_COLOR,     <0.5, 1.0, 0.0>,
        PSYS_PART_END_COLOR,       <0.0, 0.0, 1.0>,
        PSYS_PART_START_ALPHA,     1.0,
        PSYS_PART_END_ALPHA,       0.2,
        PSYS_SRC_BURST_PART_COUNT, 2,
        PSYS_SRC_BURST_RATE,       0.05,
        PSYS_PART_MAX_AGE,         0.30,
        PSYS_SRC_MAX_AGE,          0.00,
        PSYS_SRC_PATTERN,          8,
        PSYS_SRC_BURST_SPEED_MIN,  00.10,
        PSYS_SRC_BURST_SPEED_MAX,  00.10,
        PSYS_SRC_BURST_RADIUS,     00.50,
        PSYS_SRC_ANGLE_BEGIN,      0.00 *PI,
        PSYS_SRC_ANGLE_END,        1.00 *PI,
        PSYS_SRC_OMEGA,            <00.00, 00.00, 00.00>,
        PSYS_SRC_ACCEL,            <00.00, 00.00, -00.10>,
        PSYS_PART_FLAGS, (integer) ( 0
                                      | PSYS_PART_INTERP_COLOR_MASK
                                      | PSYS_PART_INTERP_SCALE_MASK
                                      | PSYS_PART_EMISSIVE_MASK
                                   )
    ]);
}

default {
    state_entry() {
        owner         = llGetOwner();

        // Compute a negative communications channel based on prim UUID
        dialogChannel = 0x80000000 | (integer) ( "0x" + (string) llGetKey() );
        inputChannel  = (integer)(llFrand(-1000000000.0) - 1000000000.0);
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                llResetTime(); // Starts tracking duration
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        } else {
            if (toucher == owner) {
                llResetTime(); // Starts tracking duration
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        }
    }

    touch_end(integer num_detected) {
        float holdTime = llGetTime();
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                if (holdTime >= 1.0) {
                    // Long press for dialog menu
                    // Handle dialog menu in its own state
                    state menu;
                } else {
                    llMessageLinked(LINK_THIS, SND_LM_DONATE, "", toucher);
                }
            }
        } else {
            if (toucher == owner) {
                if (holdTime >= 1.0) {
                    // Long press for dialog menu
                    // Handle dialog menu in its own state
                    state menu;
                } else {
                    llMessageLinked(LINK_THIS, SND_LM_DONATE, "", toucher);
                }
            }
        }
    }

    link_message(integer sender, integer num, string message, key id) {
        if (num == RCV_LM_MENU) {
            toucher = id;
            state menu;
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
        } else if (num == RCV_LM_STATUS_ON) {
            boardStatus = TRUE;
        } else if (num == RCV_LM_STATUS_OFF) {
            boardStatus = FALSE;
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
        if (num == RCV_LM_MENU) {
            toucher = id;
            state menu;
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == inputChannel) {
            boardName = llStringTrim(message, STRING_TRIM);
            linksetDataWrite(BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");

            llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, id);

            if (inputListen != -1) {
                llListenRemove(inputListen);
                inputListen = -1;
            }
        } else {
            if (message == "STOP") {
                llMessageLinked(LINK_THIS, SND_LM_IDLE, "Donation Stop", owner);
            } else if (message == "START") {
                llMessageLinked(LINK_THIS, SND_LM_DONATE, "Donation Start", id);
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
            } else if (message == "NAME") {
                if (inputListen != -1) llListenRemove(inputListen);
                inputListen = llListen(inputChannel, "", id, "");
                llSetTimerEvent(LISTEN_TTL);
                llTextBox(id, "\nEnter the Donation Board name into the box)", inputChannel);
                return; // Exit the listen event
            } else if (message == "TEXTURE") {
                state text;
            } else if (message == "EXIT") {
                state default;
            }
        }
        // Re-send the dialog to keep the menu open
        displayMainMenu();
    }

    timer() {
        if (inputListen != -1) { llListenRemove(inputListen); inputListen = -1; }
        llSetTimerEvent(0.0);
        // Return to the donation state
        llMessageLinked(LINK_THIS, SND_LM_DONATE, "", owner);
    }

    state_exit() {
        setDatastoreValues();
        llSetTimerEvent(0);
    }
}

state text {
    state_entry() {
        displayTextMenu();
    }

    link_message(integer sender, integer num, string message, key id) {
        if (num == RCV_LM_MENU) {
            toucher = id;
            state menu;
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        vector scale_vector;
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
            // Return to the previous state
            if (boardStatus) {
                llMessageLinked(LINK_THIS, SND_LM_DONATE, "", id);
            } else {
                llMessageLinked(LINK_THIS, SND_LM_IDLE, "", owner);
            }
            state default;
        } else {
            if (llGetInventoryType(message) == INVENTORY_TEXTURE) {
                llSetTexture(message, side_one);
                llMessageLinked(LINK_THIS, SND_LM_OBJMSG, llList2Json(JSON_OBJECT, ["texture", message, "face", (string)side_one]), owner);
            } else {
                llRegionSayTo(toucher, 0, "The texture is missing or not a texture: " + message);
            }
        }
        // Re-send the dialog to keep the menu open
        displayTextMenu();
    }

    timer() {
        // Return to the previous state
        if (boardStatus) {
            llMessageLinked(LINK_THIS, SND_LM_DONATE, "", owner);
        } else {
            llMessageLinked(LINK_THIS, SND_LM_IDLE, "", owner);
        }
    }

    state_exit() {
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);
        setDatastoreValues();
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
        if (num == RCV_LM_MENU) {
            toucher = id;
            state menu;
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (message == "DONE") {
            linksetDataWrite(PAY_AMTS_LSD_KEY, llList2CSV(quick_pay), "Pay Buttons Amounts");
            linksetDataWrite(DEF_PAY_LSD_KEY, (string)deflt_pay, "Default Pay Amount");
            if (boardStatus) {
                llMessageLinked(LINK_THIS, SND_LM_DONATE, "", id);
            } else {
                llMessageLinked(LINK_THIS, SND_LM_IDLE, "", owner);
            }
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
        } else if (message == "NAME") {
            if (inputListen != -1) llListenRemove(inputListen);
            inputListen = llListen(inputChannel, "", id, "");
            llSetTimerEvent(LISTEN_TTL);
            llTextBox(id, "\nEnter the Donation Board name into the box)", inputChannel);
            return; // Exit the listen event
        } else if (message == "TEXTURE") {
            state text;
        } else if (message == "EXIT") {
            if (boardStatus) {
                llMessageLinked(LINK_THIS, SND_LM_DONATE, "", id);
            } else {
                llMessageLinked(LINK_THIS, SND_LM_IDLE, "", owner);
            }
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
        // Re-send the dialog to keep the menu open
        displayAmtsMenu();
    }

    timer() {
        if (inputListen != -1) { llListenRemove(inputListen); inputListen = -1; }
        llSetTimerEvent(0.0);
        // Return to the donation state
        llMessageLinked(LINK_THIS, SND_LM_DONATE, "", owner);
    }

    state_exit() {
        setDatastoreValues();
        llSetTimerEvent(0);
    }
}

