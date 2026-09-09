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

string   VERSION = "1.0.2";

integer  ALL     = TRUE;      // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP   = FALSE;     // Set to TRUE to allow group members to manage, FALSE for owner only
integer  listenerID;
integer  objListenID;
integer  dialogHandle;
integer  warnHandle;
integer  dialogChannel;
integer  inputChannel;
integer  objChannel;           // Channel for communication between screens, based on owner
integer  listenChannel  = 0;   // Channel for chat and gestures
 
float   LISTEN_TTL      = 60.0; // Dialog Menu & listener for Webhook URL management
integer inputListen     = -1;

integer  LoggedIn       = FALSE;
integer  pageNumber     = 1;   // Dialog Menu page number
integer  tipSplit       = 100; // % given to owner (default 100)
integer  totalDonations = 0;
integer  side_one       = 0;   // Face number for front of board
integer  side_two       = 5;   // Face number for back of board
integer  particles_on   = FALSE;
integer  randParticle   = 0;
integer  boardStatus;          // TRUE if board active, FALSE if board is disabled

integer  deflt_pay      = 250; // Default donation amount
list     quick_pay      = [100, 250, 500, 1000]; // quick pay buttons

float    maxTime        = 3600.0;
float    checkInterval  = 30.0;
float    maxDistance    = 15.0;

key      setupUser;
key      current;
key      profileRequestID;
key      owner;
key      tcher = NULL_KEY;

list     sides;
list     deftextures;
list     tipNames;
list     tipAmounts;

string   Name = "";
string   fallbackTexture = "Default_Texture"; // Name of your fallback texture
string   VERT_SPACE = "\n \n \n \n \n \n \n ";
string   boardName;
string   front_texture;
string   back_texture;
string   orig_texture;
string   linksetValue;
string   menuMessage;

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
// Original donation face texture
string  ORIGTEXT_LSD_KEY   = "orig_texture";
// Donation Board Name
string  BOARD_NAME_LSD_KEY = "board_name";

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
    msg += "\nTotal contributions from this board = L$" + (string)totalDonations;

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
    string text = boardName + " Donation Board\n";
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
        llSetTexture(fallbackTexture, side_one);
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

getProfilePic(key id) {
    string url = "https://world.secondlife.com/resident/" + (string)id;
    profileRequestID = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
}

setProfilePic(string mess) {
    string profile_key_prefix = "<meta name=\"imageid\" content=\"";
    string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";

    integer pre_ind = llSubStringIndex(mess, profile_key_prefix);
    integer pre_len = llStringLength(profile_key_prefix);

    if (pre_ind == -1) {   // Second try
        pre_ind = llSubStringIndex(mess, profile_img_prefix);
        pre_len = llStringLength(profile_img_prefix);
    }

    if (pre_ind == -1) {   // Still no match?
        SetDefaultTextures();
    } else {
        pre_ind += pre_len;
        key UUID=llGetSubString(mess, pre_ind, pre_ind + 35);
        if (UUID == NULL_KEY) {
            SetDefaultTextures();
        } else {
            llSetTexture(UUID, side_one);
        }
    }
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

    // Add a little pizzazz
    randParticle = (integer)llFrand(3.0);
    if (randParticle == 1) {
        Bling();
    } else if (randParticle == 2) {
        Hearts();
    } else {
        Sparkle();
    }
    particles_on = TRUE;
    llSetTimerEvent(10);
}

ReadyForDonations(key recKey) {
    current = recKey;
    Name = llKey2Name(current);
    LoggedIn = TRUE;

    // llSetText("Truth & Beauty Beach, " + Name + " \nDonations Welcome!", <0.5,1.0,0.5>, 1.0);
    llInstantMessage(current, "You are now logged in.");
    llSetTimerEvent(checkInterval);
    getProfilePic(current);
}

list get_Textures() {
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

    menuMessage = "\nTruth & Beauty Donation Board " + VERSION;
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
    menuMessage += "\nBOARD NAME = Set the Board name hover text";
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
    main_menu += ["BOARD NAME", "TEXTURE", "EXIT"];
    ShowMenu(menuMessage, main_menu);
}

displayTextMenu() {
    list face_menu = [];
    list text_menu = [];

    llListenRemove(dialogHandle);
    dialogHandle = llListen(dialogChannel, "", tcher, "");

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
    text_menu = get_Textures();
    if (text_menu) {
        menuMessage += "\nSelect the texture to use on face " + (string)side_one + "\n";
        face_menu += text_menu;
        face_menu += ["BACK", "RESTORE", "EXIT"];
    } else {
        menuMessage += "\nNO TEXTURES FOUND\n";
    }
    ShowMenu(menuMessage, face_menu);
}

GetDatastoreValues() {
    //
    // Retrieve any configuration values stored in the linkset datastore
    //
    // Donation Board Name
    linksetValue = llLinksetDataRead(BOARD_NAME_LSD_KEY);
    if (linksetValue != "") {
        boardName = linksetValue;
    } else {
        boardName = llKey2Name(owner);
    }
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
    // Original texture linkset data key
    linksetValue = llLinksetDataRead(ORIGTEXT_LSD_KEY);
    if (linksetValue != "") {
        orig_texture = linksetValue;
    } else {
        orig_texture = front_texture;
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
}

SetDatastoreValues() {
    //
    // Set all configuration values stored in the linkset datastore
    //
    // Donation Board Name
    linksetDataWrite(owner, BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");
    // Payment Avatar UUID linkset data key
    linksetDataWrite(owner, PAY_UUID_LSD_KEY, (string)current, "Payment receiving UUID");
    // Total amount received linkset data key
    linksetDataWrite(owner, TOTAL_AMT_LSD_KEY, (string)totalDonations, "Total amount donated");
    // Front face texture linkset data key
    linksetDataWrite(owner, FRONT_LSD_KEY, (string)front_texture, "Front Side Texture");
    // Back face texture linkset data key
    linksetDataWrite(owner, BACK_LSD_KEY, (string)back_texture, "Back Side Texture");
    // Original face texture linkset data key
    linksetDataWrite(owner, ORIGTEXT_LSD_KEY, (string)orig_texture, "Original Front Texture");
    // Solo or All linkset data key
    linksetDataWrite(owner, SOLO_LSD_KEY, (string)ALL, "Solo or All Boards");
    // Group or Owner access linkset data key
    linksetDataWrite(owner, GROUP_LSD_KEY, (string)GROUP, "Group or Owner access");
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
        // Send the message to other objects in region with same owner listening on this channel
        if (cmd == "donation stop") {
            llRegionSay(objChannel, "Donation Stop");
            stopDonation();
        } else if (cmd == "donation start") {
            llRegionSay(objChannel, "Donation Start");
            startDonation();
        } else if (cmd == "donation info") {
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

ParticlesOff() {
    llParticleSystem([]);
}

Bling() {
    ParticlesOff();
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

Hearts() {
    ParticlesOff();
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

Sparkle() {
    ParticlesOff();
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
        // Turn off touch to pay until we are ready to receive payments
        stopDonation();
        GetDefaultTextures();
        tcher     = NULL_KEY;
        owner     = llGetOwner();

        // Retrieve any stored configuration or set defaults
        GetDatastoreValues();

        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);

        // Compute a large negative channel number based on the object owner
        // All boards owned by the same owner will use the same channel
        objChannel = 0x80000000 | (integer) ( "0x" + (string) owner );
        objChannel += 1;
        llListenRemove(listenerID);
        listenerID = llListen(listenChannel, "", owner, "");
        llListenRemove(objListenID);
        objListenID = llListen(objChannel, "", NULL_KEY, "");
        // Compute a negative communications channel based on prim UUID
        dialogChannel = 0x80000000 | (integer) ( "0x" + (string) llGetKey() );
        inputChannel  = (integer)(llFrand(-1000000000.0) - 1000000000.0);

        Sparkle();
        particles_on = TRUE;
        llSetTimerEvent(10);

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
            startDonation();
            state donate;
        } else {
            llOwnerSay("⚠️ This script needs debit permissions to send money.");
            stopDonation();
            state menu;
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
        if (particles_on) {
            particles_on = FALSE;
            ParticlesOff();
            llSetTimerEvent(0.0);
        }

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
        if (req != profileRequestID) return;

        setProfilePic(body);
        profileRequestID = NULL_KEY;
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

        // Retrieve any stored configuration parameters from linkset datastore
        // If not stored then use defaults
        GetDatastoreValues();
        SetDatastoreValues();
    }
}

state menu {
    state_entry() {
        displayMainMenu();
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == inputChannel) {
            boardName = llStringTrim(message, STRING_TRIM);
            linksetDataWrite(owner, BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");

            updateHoverText();

            if (inputListen != -1) {
                llListenRemove(inputListen);
                inputListen = -1;
            }
        } else {
            if (message == "STOP") {
                if (ALL) {
                    // Send the message to other boards in region with same owner listening on this channel
                    llRegionSay(objChannel, "Donation Stop");
                }
                stopDonation();
                state idle;
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
            } else if (message == "BOARD NAME") {
                if (inputListen != -1) llListenRemove(inputListen);
                inputListen = llListen(inputChannel, "", id, "");
                llSetTimerEvent(LISTEN_TTL);
                llTextBox(id, "\nEnter the Donation Board name into the box)", inputChannel);
                return; // Exit the listen event
            } else if (message == "TEXTURE") {
                state text;
            } else if (message == "EXIT") {
                // Return to the donation state
                state donate;
            }
        }
        // Re-send the dialog to keep the menu open
        displayMainMenu();
    }

    timer() {
        if (inputListen != -1) { llListenRemove(inputListen); inputListen = -1; }
        llSetTimerEvent(0.0);
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

    timer() {
        if (particles_on) {
            particles_on = FALSE;
            ParticlesOff();
            llSetTimerEvent(0.0);
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
}

state idle {
    state_entry() {
        // Disable donations
        stopDonation();
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

state text
{
    state_entry() {
        displayTextMenu();
    }

    listen(integer channel, string name, key id, string message) {
        vector scale_vector;
        if (message == "ALL") {
            ALL = TRUE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
        } else if (message == "SOLO") {
            ALL = FALSE;
            linksetDataWrite(tcher, SOLO_LSD_KEY, (string)ALL, "All or Solo Board");
        } else if (message == "FLIP HORIZ") {
            // Flips the texture horizontally on selected face, keeping vertical scale
            scale_vector = llGetTextureScale(side_one);
            llScaleTexture(-(scale_vector.x), scale_vector.y, side_one);
        } else if (message == "FLIP VERT") {
            // Flips the texture vertically on selected face, keeping horizontal scale
            scale_vector = llGetTextureScale(side_one);
            llScaleTexture(scale_vector.x, -(scale_vector.y), side_one);
        } else if (message == "PROFILE") {
            getProfilePic(owner);
        } else if (message == "RESTORE") {
            linksetValue = llLinksetDataRead(ORIGTEXT_LSD_KEY);
            if (linksetValue != "") {
                llSetTexture(linksetValue, side_one);
            } else {
                llSetTexture(front_texture, side_one);
                linksetDataWrite(owner, ORIGTEXT_LSD_KEY, front_texture, "Original Board Textures");
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
                state donate;
            } else {
                state idle;
            }
        } else {
            if (llGetInventoryType(message) == INVENTORY_TEXTURE) {
                llSetTexture(message, side_one);
                if (ALL) {
                    // Pack the 2 key/value pairs as a JSON string
                    llRegionSay(objChannel, llList2Json(JSON_OBJECT, ["texture", message, "face", (string)side_one]));
                }
            } else {
                llRegionSayTo(tcher, 0, "The texture is missing or not a texture: " + message);
            }
        }
        // Re-send the dialog to keep the menu open
        displayTextMenu();
    }

    http_response(key req, integer status, list meta, string body) {
        if (req != profileRequestID) return;

        setProfilePic(body);
        profileRequestID = NULL_KEY;
    }

    timer() {
        // Return to the previous state
        if (boardStatus) {
            state donate;
        } else {
            state idle;
        }
    }

    state_exit() {
        front_texture = llGetTexture(side_one);
        back_texture = llGetTexture(side_two);
        SetDatastoreValues();
        llSetTimerEvent(0);
    }
}

state warn
{
    state_entry() {
        integer warnChannel = -999999;
        llListenRemove(warnHandle);
        warnHandle = llListen(warnChannel, "", tcher, "");

        llDialog(tcher, "\nSelect a face to texture first\n", ["OK"], warnChannel);
        llSetTimerEvent(30.0); // 30-second timer
    }

    listen(integer channel, string name, key id, string message) {
        llSetTimerEvent(0.0);       // Stop timer
        llListenRemove(warnHandle); // Remove listener
        state text;
    }

    timer() {
        llSetTimerEvent(0.0);       // Stop timer
        llListenRemove(warnHandle); // Remove listener
        state text;
    }
}
