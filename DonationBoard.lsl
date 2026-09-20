///////////////////////////////////////////////////////////////////////////////////
//     Donation Board LSL script with Pay/Touch or Message on Listen Channel     //
//                                                                               //
// Message or Touch by owner of object toggles Menu and Payment states           //
// Listens on channel 0 for trigger messages to board                            //
// Messages other boards in region with same owner to trigger toggle command     //
// Sends the parcel stream URL to the Stream Relay object on group owned land    //
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
// 2026-Sep-15 Auto set parcel stream URL         //
// 2026-Sep-16 Set owner key before group deed    //
//             Set owner key in linkset datastore //
// 2026-Sep-18 Send stream URL to Stream Relay on //
//             parcel deeded to group             //
//                                                //
////////////////////////////////////////////////////

string   VERSION = "1.1.0";

integer  ALL     = TRUE;      // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP   = TRUE;      // Set to TRUE to allow group members to manage, FALSE for owner only
integer  DEEDED  = FALSE;     // TRUE if the parcel has been deeded to a group
integer  listenerID;
integer  objListenID;
integer  objChannel;           // Channel for communication between screens, based on owner
// integer  relayListenID;
integer  relayChannel;         // Channel for communication with the Stream Relay, based on parcel ID
integer  listenChannel  = 0;   // Channel for chat and gestures
 
integer  loggedIn       = FALSE;
integer  needInit       = TRUE; // Prim initialization is needed
integer  showTotal      = TRUE;
integer  debug          = FALSE;
integer  twoSplit       = 80;  // % shared if group member logged in
integer  tipSplit       = 0;   // % shared
integer  totalDonations = 0;
integer  side_one       = 0;   // Face number for front of board
integer  particles_on   = FALSE;
integer  randParticle   = 0;
integer  boardStatus;          // TRUE if board active, FALSE if board is disabled

integer  deflt_pay      = 250; // Default donation amount
list     quick_pay      = [100, 250, 500, 1000]; // quick pay buttons
list     deftextures;

float    checkInterval  = 60.0;
float    maxDistance    = 15.0;

key      current;
key      profileRequestID;
key      owner;
key      toucher = NULL_KEY;

string   DEF_STREAM_URL = "http://server1.chilltrax.com:9000";
string   VERT_SPACE     = "\n \n \n \n \n \n ";
string   sideTexture    = "Sides";
string   customName     = "";
string   streamURL      = "";
string   boardName      = "";
string   front_texture;
string   orig_texture;
string   linksetValue;

// Linkset Data Keys
// Must match the definitions in DialogMenu.lsl
//
// Owner of Donation Board object, prior to deeding to group
string  OWNER_LSD_KEY      = "owner";
// Donation Board version
string  VERSION_LSD_KEY    = "version";
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
//
// Linked Message Numbers
//
// Send to dialog menu
integer SND_LM_MENU        = 100;
integer SND_LM_DISTANCE    = 125;
integer SND_LM_GROUP       = 150;
integer SND_LM_HOVER       = 160;
integer SND_LM_LOGIN       = 175;
integer SND_LM_STATUS_ON   = 200;
integer SND_LM_STATUS_OFF  = 210;
integer SND_LM_SHARE       = 250;
integer SND_LM_STREAM      = 300;

updateHoverText() {
    string text = boardName + "\n";
    string offTexture = "Maintenance";
    vector color;

    if (boardStatus) {
        if (llGetTexture(side_one) == offTexture) {
            readyForDonations(owner);
        }
        if (showTotal) {
            if (totalDonations > 0) {
                text += "L$" + (string)totalDonations + " donated so far!";
            } else {
                text += "Empty - Be the first to donate!";
            }
        }
        color = <0.0, 1.0, 0.0>; // Green hover text
    } else {
        text += "Inactive, temporarily unavailable";
        color = <1.0, 1.0, 0.0>; // Yellow hover text
        if (llGetInventoryType(offTexture) == INVENTORY_TEXTURE) {
            llSetTexture(offTexture, side_one);
        }
    }
    text += VERT_SPACE;
    llSetText(text, color, 1.0);
}

stopDonation() {
    llSetClickAction(CLICK_ACTION_TOUCH);
    llSetPayPrice(deflt_pay, quick_pay);
    boardStatus = FALSE;
    updateHoverText();
    llMessageLinked(LINK_THIS, SND_LM_STATUS_OFF, "", owner);
}

startDonation() {
    llSetClickAction(CLICK_ACTION_PAY);
    llSetPayPrice(deflt_pay, quick_pay);
    boardStatus = TRUE;
    updateHoverText();
    llMessageLinked(LINK_THIS, SND_LM_STATUS_ON, "", owner);
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
    msg += "\nShare percent to logged in user = " + (string)twoSplit + "%";
    if (loggedIn) {
        string username = llKey2Name(current);
        if (username != "") {
            msg += "\nLogged in user = " + username;
        }
    } else {
        msg += "\nNo user currently logged in, all donations to owner";
    }
    linksetValue = llLinksetDataRead(STREAM_URL_LSD_KEY);
    if (linksetValue != "") {
        msg += "\nAuto Set parcel stream URL = " + linksetValue;
    } else {
        msg += "\nNo parcel stream URL currently set";
    }
    msg += "\nTotal contributions from this board = L$" + (string)totalDonations;

    if (toucher == owner) {
        llOwnerSay(msg);
    } else {
        if (toucher) {
            llRegionSayTo(toucher, 0, msg);
        } else {
            llOwnerSay(msg);
        }
    }
}

string getParcelName() {
    list details = llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_NAME]);
    return llList2String(details, 0);
}

howtoPay() {
    llInstantMessage(toucher, "Please right-click the Donation Board and select 'Pay' to make a donation.");
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

getDefaultTextures() {
    integer i;
    integer faces = llGetNumberOfSides();
    for (i = 0; i < faces; i++) {
        deftextures += llGetTexture(i);
    }
}

setDefaultTextures() {
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
        setDefaultTextures();
    } else {
        pre_ind += pre_len;
        key UUID=llGetSubString(mess, pre_ind, pre_ind + 35);
        if (UUID == NULL_KEY) {
            setDefaultTextures();
        } else {
            llSetTexture(UUID, side_one);
        }
    }
}

acceptDonation(key id, integer amount) {
    totalDonations += amount;
    string giverName = llKey2Name(id);

    linksetDataWrite(TOTAL_AMT_LSD_KEY, (string)totalDonations, "Total amount donated");

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
        llGiveMoney(owner, ownerShare);
        llInstantMessage(owner, "You retained L$" + (string)ownerShare + " from a donation.");
    }

    // Add a little pizzazz
    randParticle = (integer)llFrand(3.0);
    if (randParticle == 1) {
        bling();
    } else if (randParticle == 2) {
        hearts();
    } else {
        sparkle();
    }
    particles_on = TRUE;
    llSetTimerEvent(10);
}

readyForDonations(key recKey) {
    current = recKey;
    if (customName == "") {
        boardName = llKey2Name(current) + " Tip Board";
    } else {
        boardName = customName;
    }
    llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");
    if (current == owner) {
        tipSplit = 0;
    } else {
        tipSplit = twoSplit;
    }
    loggedIn = TRUE;
    llInstantMessage(current, "You are now logged in.");
    llSetTimerEvent(checkInterval);
    setStreamURL("", current);
    llMessageLinked(LINK_THIS, SND_LM_LOGIN, (string)loggedIn, current);
    getProfilePic(current);
    llMessageLinked(LINK_THIS, SND_LM_SHARE, llList2Json(JSON_OBJECT, ["split", (string)tipSplit, "share", (string)twoSplit]), "");
}

getDatastoreValues() {
    //
    // Retrieve any configuration values stored in the linkset datastore
    //
    // Donation Board Name
    linksetValue = llLinksetDataRead(BOARD_NAME_LSD_KEY);
    if (linksetValue != "") {
        boardName = linksetValue;
    } else {
        boardName = llKey2Name(owner) + " Tip Board";
    }
    llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");
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
    // Default Pay dialog amount
    linksetValue = llLinksetDataRead(DEF_PAY_LSD_KEY);
    if (linksetValue != "") {
        deflt_pay = (integer)linksetValue;
    }
    // Pay dialog button amounts
    linksetValue = llLinksetDataRead(PAY_AMTS_LSD_KEY);
    if (linksetValue != "") {
        quick_pay = csv2list(linksetValue);
    }
    // Parcel stream URL
    streamURL = llLinksetDataRead(STREAM_URL_LSD_KEY);
    // Owner share percent
    linksetValue = llLinksetDataRead(SHARE_LSD_KEY);
    if (linksetValue != "") {
        tipSplit = (integer)linksetValue;
    } else {
        if (loggedIn) {
            tipSplit = twoSplit;
        } else {
            tipSplit = 0;
        }
    }
    // Make sure the Donation Board version is written
    linksetDataWrite(VERSION_LSD_KEY, VERSION, "Donation Board Version");
}

setDatastoreValues() {
    //
    // Set all configuration values stored in the linkset datastore
    //
    // Donation Board version
    linksetDataWrite(VERSION_LSD_KEY, VERSION, "Donation Board Version");
    // Donation Board Name
    linksetDataWrite(BOARD_NAME_LSD_KEY, boardName, "Donation Board Name");
    // Payment Avatar UUID linkset data key
    linksetDataWrite(PAY_UUID_LSD_KEY, (string)current, "Payment receiving UUID");
    // Total amount received linkset data key
    linksetDataWrite(TOTAL_AMT_LSD_KEY, (string)totalDonations, "Total amount donated");
    // Front face texture linkset data key
    linksetDataWrite(FRONT_LSD_KEY, front_texture, "Front Side Texture");
    // Original face texture linkset data key
    linksetDataWrite(ORIGTEXT_LSD_KEY, (string)orig_texture, "Original Front Texture");
    // Solo or All linkset data key
    linksetDataWrite(SOLO_LSD_KEY, (string)ALL, "Solo or All Boards");
    // Group or Owner access linkset data key
    linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group or Owner access");
    // Default Pay dialog amount
    linksetDataWrite(DEF_PAY_LSD_KEY, (string)deflt_pay, "Default Pay Amount");
    // Pay dialog button amounts
    linksetDataWrite(PAY_AMTS_LSD_KEY, llList2CSV(quick_pay), "Pay Buttons Amounts");
    // Owner share percent
    linksetDataWrite(SHARE_LSD_KEY, (string)tipSplit, "Owner donation percent");
    // Parcel stream URL
    if ((streamURL != "") && (STREAM_URL_LSD_KEY != "")) {
        linksetDataWrite(STREAM_URL_LSD_KEY, streamURL, "Parcel Stream URL");
    }
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
        } else if (cmd == "group") {
            GROUP = TRUE;
            linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group Access");
            llMessageLinked(LINK_THIS, SND_LM_GROUP, "Group", owner);
        } else if (cmd == "owner") {
            GROUP = FALSE;
            linksetDataWrite(GROUP_LSD_KEY, (string)GROUP, "Group Access");
            llMessageLinked(LINK_THIS, SND_LM_GROUP, "Owner", owner);
        } else if (llJsonValueType(msg, []) != JSON_INVALID) {
            string txt = llJsonGetValue(msg, ["texture"]);
            string fce = llJsonGetValue(msg, ["face"]);
            if (llGetInventoryType(txt) == INVENTORY_TEXTURE) {
                llSetTexture(txt, (integer)fce);
            } else {
                if (debug) llOwnerSay("The texture is missing or not a texture: " + txt);
            }
        }
    }
}

checkGone(key avatar) {
    vector Pos = llList2Vector(llGetObjectDetails(avatar, [OBJECT_POS]), 0);
    vector jarPos = llGetPos();
    float distance = llVecDist(Pos, jarPos);

    if (distance > maxDistance) {
        llInstantMessage(avatar, "You were too far from the donation board and have been logged out.");
        loggedIn = FALSE;
        tipSplit = 0;
        current = owner;
        setStreamURL("", current);
        llMessageLinked(LINK_THIS, SND_LM_LOGIN, (string)loggedIn, current);
        if (customName == "") {
            boardName = llKey2Name(current) + " Tip Board";
        } else {
            boardName = customName;
        }
        llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");
        llMessageLinked(LINK_THIS, SND_LM_SHARE, llList2Json(JSON_OBJECT, ["split", (string)tipSplit, "share", (string)twoSplit]), "");
        getProfilePic(current);
        llSetTimerEvent(0.0);
    }
}

setLoggedIn() {
    if (!loggedIn) {
        current = toucher;
        boardName = llKey2Name(current) + " Tip Board";
        loggedIn = TRUE;
        setStreamURL("", current);
        llMessageLinked(LINK_THIS, SND_LM_LOGIN, (string)loggedIn, current);
        if (current == owner) {
            tipSplit = 0;
        } else {
            tipSplit = twoSplit;
        }
        getProfilePic(current);

        llSetText("🎧  " + boardName + " 🎧\nTips Welcome!" + VERT_SPACE, <0.5,1.0,0.5>, 1.0);
        llInstantMessage(current, "You are now logged in as DJ.");
        llMessageLinked(LINK_THIS, SND_LM_SHARE, llList2Json(JSON_OBJECT, ["split", (string)tipSplit, "share", (string)twoSplit]), "");
        llSetTimerEvent(checkInterval);
    } else if (toucher == current) {
        current = owner;
        loggedIn = FALSE;
        tipSplit = 0;
        setStreamURL("", current);
        llMessageLinked(LINK_THIS, SND_LM_LOGIN, (string)loggedIn, current);
        if (customName == "") {
            boardName = llKey2Name(current) + " Tip Board";
        } else {
            boardName = customName;
        }
        llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");
        getProfilePic(current);
        startDonation();
        llInstantMessage(toucher, "You have logged out.");
        llMessageLinked(LINK_THIS, SND_LM_SHARE, llList2Json(JSON_OBJECT, ["split", (string)tipSplit, "share", (string)twoSplit]), "");
        llSetTimerEvent(0.0);
    } else {
        llInstantMessage(toucher, "A DJ is already logged in.");
    }
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

setOwner() {
    vector pos      = llGetPos();
    list   details  = llGetParcelDetails(pos, [PARCEL_DETAILS_OWNER, PARCEL_DETAILS_GROUP]);
    key    ownerKey = llList2Key(details, 0);
    key    groupKey = llList2Key(details, 1);

    linksetValue = llLinksetDataRead(OWNER_LSD_KEY);
    if (linksetValue == "") {
        owner = llGetOwner();
        linksetDataWrite(OWNER_LSD_KEY, (string)owner, "Donation Board Owner");
    } else {
        owner = (key)linksetValue;
    }
    if (owner == llGetOwner()) {
        DEEDED = FALSE;
    } else {
        DEEDED = TRUE;
    }

    // If the parcel is group-owned, the owner key and group key are identical
    if ((ownerKey == groupKey) && (groupKey != NULL_KEY)) {
        if (!DEEDED) llOwnerSay("Parcel is deeded to a group. Group: " + "secondlife:///app/group/" + (string)groupKey + "/about");
        DEEDED = TRUE;
    } else {
        if (DEEDED) llOwnerSay("Parcel is privately owned and not deeded to a group.");
        DEEDED = FALSE;
    }
}

initPrim() {
    integer i;
    integer backFace = 5;
    string  slurl    = getBoardSlurl();
    string  parcel   = getParcelName();
    string  currURL  = llGetParcelMusicURL();

    setOwner();

    // Get and set the original parcel stream URL
    STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)owner;
    streamURL = llLinksetDataRead(STREAM_URL_LSD_KEY);
    if (streamURL == "") {
        // No parcel stream URL is stored
        if (currURL == "") {
            // No parcel stream URL is set or we can't get it
            setParcelMusicURL(DEF_STREAM_URL);
            streamURL = DEF_STREAM_URL;
            chkMusicURL(streamURL);
        } else {
            streamURL = currURL;
        }
        linksetDataWrite(STREAM_URL_LSD_KEY, streamURL, "Parcel Stream URL");
    }
    llMessageLinked(LINK_THIS, SND_LM_STREAM, streamURL, owner);

    // Set default texture and glow of beveled sides and back
    if (llGetInventoryType(sideTexture) == INVENTORY_TEXTURE) {
        for (i = 1; i < backFace; i++) {
            llSetTexture(sideTexture, i);
            llSetPrimitiveParams([PRIM_GLOW, i, 0.1]);
        }
    }
    // Set back transparent
    llSetAlpha(0.0, backFace);
    getDefaultTextures();

    stopDonation();

    llOwnerSay("The Truth & Beauty Donation Board located at " + slurl + " is now active.");
    llOwnerSay("Donation Board updates are free for life and will be available at:");
    llOwnerSay("    https://github.com/missyrestless/DonationBoard/releases");
    llOwnerSay("The latest Truth & Beauty Donation Board documentation can be found at:");
    llOwnerSay("    https://github.com/missyrestless/DonationBoard#readme");

    // Write the version to the linkset datastore
    linksetDataWrite(VERSION_LSD_KEY, VERSION, "Donation Board Version");
    // Retrieve any stored configuration parameters from linkset datastore
    // If not stored then use defaults
    getDatastoreValues();
    boardName = parcel + " Donation Board";
    llMessageLinked(LINK_THIS, SND_LM_HOVER, boardName, "");
    customName = boardName;
    setDatastoreValues();
    needInit = FALSE;
}

list csv2list(string csv) {
    list strList = llCSV2List(csv);
    list intList = [];

    integer i;
    integer len = llGetListLength(strList);

    for (i = 0; i < len; ++i) {
        // Typecast each string element to an integer
        integer val = (integer)llList2String(strList, i);
        intList += [val];
    }
    return intList;
}

processAction(integer action, string name, string value) {
    if (action == LINKSETDATA_RESET) {
        if (debug) llOwnerSay("Link set datastore has been cleared.");
        llResetScript();
    } else if (action == LINKSETDATA_DELETE) {
        if (debug) llOwnerSay("Link set datastore key \"" + name + "\" has been deleted.");
    } else if (action == LINKSETDATA_UPDATE) {
        if (debug) llOwnerSay("Link set datastore key \"" + name + "\" = \"" + value + "\".");
    }
}

string lnk_msg(integer sender, integer num, string message, key id) {
    // Receive from Dialog Menu
    integer RCV_LM_ALL         = 10;
    integer RCV_LM_SOLO        = 15;
    integer RCV_LM_DONATE      = 20;
    integer RCV_LM_IDLE        = 30;
    integer RCV_LM_INFO        = 40;
    integer RCV_LM_DATA_WRITE  = 45;
    integer RCV_LM_FRONT_TEXT  = 48;
    integer RCV_LM_GROUP       = 50;
    integer RCV_LM_TOTAL       = 55;
    integer RCV_LM_OBJMSG      = 60;
    integer RCV_LM_DISTANCE    = 65;
    integer RCV_LM_HOVER       = 70;
    integer RCV_LM_LOGIN       = 75;
    integer RCV_LM_PROFILE     = 80;
    integer RCV_LM_STREAM      = 88;
    integer RCV_LM_SHARE       = 90;
    integer RCV_LM_READ_AMTS   = 95;
    integer RCV_LM_DEBUG       = 99;

    // Message to send to other boards
    string msg = message;
    string ret_state = "";

    if (num == RCV_LM_ALL) {
        ALL = TRUE;
    } else if (num == RCV_LM_SOLO) {
        ALL = FALSE;
    } else if (num == RCV_LM_DONATE) {
        toucher = id;
        if (toucher == owner) {
            current = owner;
        } else {
            setLoggedIn();
        }
        readyForDonations(current);
        ret_state = "donate";
    } else if (num == RCV_LM_IDLE) {
        ret_state = "idle";
    } else if (num == RCV_LM_INFO) {
        stateDonation();
    } else if (num == RCV_LM_DATA_WRITE) {
        setDatastoreValues();
    } else if (num == RCV_LM_FRONT_TEXT) {
        front_texture = message;
        linksetDataWrite(FRONT_LSD_KEY, front_texture, "Front Side Texture");
    } else if (num == RCV_LM_GROUP) {
        if (message == "Group") {
            GROUP = TRUE;
        } else if (message == "Owner") {
            GROUP = FALSE;
        }
    } else if (num == RCV_LM_LOGIN) {
        toucher = id;
        setLoggedIn();
    } else if (num == RCV_LM_DISTANCE) {
        maxDistance = (float)message;
    } else if (num == RCV_LM_HOVER) {
        boardName = message;
        customName = boardName;
        // Do not send a message to other boards
        msg = "";
        updateHoverText();
    } else if (num == RCV_LM_PROFILE) {
        getProfilePic(current);
    } else if (num == RCV_LM_STREAM) {
        setStreamURL(message, id);
        // Do not send a message to other boards
        msg = "";
    } else if (num == RCV_LM_SHARE) {
        twoSplit = (integer)message;
        if (loggedIn) {
            tipSplit = twoSplit;
        } else {
            tipSplit = 0;
        }
        // Do not send a message to other boards
        msg = "";
    } else if (num == RCV_LM_READ_AMTS) {
        // Default Pay dialog amount
        linksetValue = llLinksetDataRead(DEF_PAY_LSD_KEY);
        if (linksetValue != "") {
            deflt_pay = (integer)linksetValue;
        }
        // Pay dialog button amounts
        linksetValue = llLinksetDataRead(PAY_AMTS_LSD_KEY);
        if (linksetValue != "") {
            quick_pay = csv2list(linksetValue);
        }
        if (boardStatus) {
            startDonation();
        } else {
            stopDonation();
        }
    } else if (num == RCV_LM_TOTAL) {
        showTotal = !showTotal;
        updateHoverText();
    } else if (num == RCV_LM_DEBUG) {
        debug = !debug;
    }

    if (ALL) {
        // Send the message to other boards in region with same owner listening on this channel
        if (msg != "") {
            llRegionSay(objChannel, msg);
        }
    }
    return ret_state;
}

chkMusicURL(string url) {
    // Check if the update actually took place
    if (llGetParcelMusicURL() == url) {
        if (debug) llOwnerSay("Music URL successfully updated!");
    } else {
        if (debug) llOwnerSay("Failure: Could not set music URL. Check land ownership or group deeding permissions.");
    }
}

setParcelMusicURL(string URL) {
    if (DEEDED) {
        llRegionSay(relayChannel, URL);
    } else {
        llSetParcelMusicURL(URL);
    }
}

setStreamURL(string url, key id) {
    STREAM_URL_LSD_KEY = STREAM_URL_PREFIX + (string)id;
    streamURL = llLinksetDataRead(STREAM_URL_LSD_KEY);
    if (streamURL != url) {
        if (url != "") {
            linksetDataWrite(STREAM_URL_LSD_KEY, url, "Parcel Stream URL");
            streamURL = url;
        }
    }
    if (streamURL != "") {
        llMessageLinked(LINK_THIS, SND_LM_STREAM, streamURL, id);
        if (llGetParcelMusicURL() != streamURL) {
            setParcelMusicURL(streamURL);
            chkMusicURL(streamURL);
        }
    }
}

default {
    state_entry() {
        // Turn off touch to pay until we are ready to receive payments
        stopDonation();
        getDefaultTextures();
        toucher   = NULL_KEY;
        // setOwner() sets the owner global variable and stores that value in the linkset datastore
        // Needed to work with group owned boards since llGetOwner() returns the group key
        // We need to know which user has owner management privileges
        setOwner();

        // 1. Retrieve the parcel ID (UUID key) for the object's current position
        list details = llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_ID]);
        key parcelID = llList2Key(details, 0);

        // 2. Extract an 8-character hex block (e.g., the first 8 characters)
        string hexPart = llGetSubString((string)parcelID, 0, 7);

        // 3. Convert the hex string to an integer and force it negative
        // Adding "0x" allows LSL to implicitly typecast the hex string to an integer.
        // Bitwise OR with 0x80000000 sets the sign bit, forcing a large negative range.
        relayChannel = 0x80000000 | (integer)("0x" + hexPart);

        // No need to listen on the relay channel as messages are only outgoing
        // llListenRemove(relayListenID);
        // relayListenID = llListen(relayChannel, "", NULL_KEY, "");

        // Compute a large negative channel number based on the object owner
        // All boards owned by the same owner will use the same channel
        objChannel = 0x80000000 | (integer) ( "0x" + (string) owner );
        objChannel += 1;
        llListenRemove(listenerID);
        listenerID = llListen(listenChannel, "", owner, "");
        llListenRemove(objListenID);
        objListenID = llListen(objChannel, "", NULL_KEY, "");

        // Set Prim face textures if not already set
        if (needInit) {
            initPrim();
        }

        // Retrieve any stored configuration or set defaults
        getDatastoreValues();

        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);
        // Send max distance
        llMessageLinked(LINK_THIS, SND_LM_DISTANCE, (string)maxDistance, "");

        sparkle();
        particles_on = TRUE;
        llSetTimerEvent(10);

        llRequestPermissions(owner, PERMISSION_DEBIT);
    }

    run_time_permissions(integer perms) {
        // If Debit permissions are granted, set up the pay price for this single-price vendor
        if (perms & PERMISSION_DEBIT) {
            llOwnerSay("Donation Board is ready and online.");
        } else {
            tipSplit = 0;
            twoSplit = 0;
            llOwnerSay("WARNING: This script needs debit permissions to share donations.");
        }
        readyForDonations(owner);
        state donate;
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        } else {
            if (toucher == owner) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        }
    }

    link_message(integer sender, integer num, string message, key id) {
        string ret = lnk_msg(sender, num, message, id);

        if (ret == "donate") {
            state donate;
        } else if (ret == "idle") {
            state idle;
        }
    }

    money(key id, integer amount) {
        acceptDonation(id, amount);
    }

    timer() {
        if (particles_on) {
            particles_on = FALSE;
            particlesOff();
            llSetTimerEvent(0.0);
        }

        if (!loggedIn) return;

        checkGone(current);
    }

    http_response(key req, integer status, list meta, string body) {
        if (req != profileRequestID) return;

        setProfilePic(body);
        profileRequestID = NULL_KEY;
    }

    linkset_data(integer action, string name, string value) {
        processAction(action, name, value);
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
        initPrim();
    }
}

state donate {
    state_entry() {
        // Turn on touch to pay
        startDonation();
        toucher = NULL_KEY;
    }

    listen(integer channel, string name, key id, string message) {
        processMessage(channel, message);
        string cmd = llToLower(message);

        if (cmd == "donation stop") {
            state idle;
        }
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                if (toucher == owner) {
                    llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
                } else {
                    setLoggedIn();
                }
                readyForDonations(current);
                startDonation();
                if (loggedIn) llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        } else {
            if (toucher == owner) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            } else {
                howtoPay();
                toucher = NULL_KEY;
            }
        }
    }

    link_message(integer sender, integer num, string message, key id) {
        string ret = lnk_msg(sender, num, message, id);

        if (ret == "donate") {
            state donate;
        } else if (ret == "idle") {
            state idle;
        }
    }

    http_response(key req, integer status, list meta, string body) {
        if (req != profileRequestID) return;

        setProfilePic(body);
        profileRequestID = NULL_KEY;
    }

    money(key id, integer amount) {
        acceptDonation(id, amount);
    }

    timer() {
        if (particles_on) {
            particles_on = FALSE;
            particlesOff();
            llSetTimerEvent(0.0);
        }

        if (!loggedIn) return;

        checkGone(current);
    }

    linkset_data(integer action, string name, string value) {
        processAction(action, name, value);
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
        toucher = NULL_KEY;
    }

    listen(integer channel, string name, key id, string message) {
        processMessage(channel, message);
        string cmd = llToLower(message);

        if (cmd == "donation start") {
            state donate;
        }
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            }
        } else {
            if (toucher == owner) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            }
        }
    }

    http_response(key req, integer status, list meta, string body) {
        if (req != profileRequestID) return;

        setProfilePic(body);
        profileRequestID = NULL_KEY;
    }

    link_message(integer sender, integer num, string message, key id) {
        string ret = lnk_msg(sender, num, message, id);

        if (ret == "donate") {
            state donate;
        } else if (ret == "idle") {
            state idle;
        }
    }

    linkset_data(integer action, string name, string value) {
        processAction(action, name, value);
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
