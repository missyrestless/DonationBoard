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

string   VERSION = "1.0.3";

integer  ALL     = TRUE;      // Set to TRUE to effect all boards, FALSE for single board
integer  GROUP   = FALSE;     // Set to TRUE to allow group members to manage, FALSE for owner only
integer  listenerID;
integer  objListenID;
integer  warnHandle;
integer  dialogChannel;
integer  objChannel;           // Channel for communication between screens, based on owner
integer  listenChannel  = 0;   // Channel for chat and gestures
 
integer  LoggedIn       = FALSE;
integer  pageNumber     = 1;   // Dialog Menu page number
integer  oneSplit       = 100; // % given to owner if nobody logged in
integer  twoSplit       =  80; // % given to owner if group member logged in
integer  tipSplit       = 100; // % given to owner
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
key      toucher = NULL_KEY;

list     sides;
list     deftextures;
list     tipNames;
list     tipAmounts;

string   Name = "";
string   VERT_SPACE = "\n \n \n \n \n \n \n ";
string   boardName;
string   front_texture;
string   back_texture;
string   orig_texture;
string   linksetValue;

// Linkset Data Keys
// Must match the definitions in DialogMenu.lsl
//
// Donation Board version
string  VERSION_LSD_KEY    = "version";
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
//
// Linked Message Numbers
//
// Send to dialog menu
integer SND_LM_MENU        = 100;
integer SND_LM_GROUP       = 150;
integer SND_LM_STATUS_ON   = 200;
integer SND_LM_STATUS_OFF  = 210;
// Receive from Dialog Menu
integer RCV_LM_ALL         = 10;
integer RCV_LM_SOLO        = 15;
integer RCV_LM_DONATE      = 20;
integer RCV_LM_IDLE        = 30;
integer RCV_LM_INFO        = 40;
integer RCV_LM_GROUP       = 50;
integer RCV_LM_OBJMSG      = 60;
integer RCV_LM_HOVER       = 70;
integer RCV_LM_PROFILE     = 80;

stopDonation() {
    llSetClickAction(CLICK_ACTION_TOUCH);
    llSetPayPrice(PAY_HIDE, [PAY_HIDE ,PAY_HIDE, PAY_HIDE, PAY_HIDE]);
    boardStatus = FALSE;
    llMessageLinked(LINK_THIS, SND_LM_STATUS_OFF, "", owner);
}

startDonation() {
    llSetClickAction(CLICK_ACTION_PAY);
    llSetPayPrice(deflt_pay, quick_pay);
    boardStatus = TRUE;
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

getDefaultTextures() {
    integer i;
    integer faces = llGetNumberOfSides();
    for (i = 0; i < faces; i++) {
        sides += i;
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
        llInstantMessage(owner, "You retained L$" + (string)ownerShare + " from a tip.");
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
    Name = llKey2Name(current);
    LoggedIn = TRUE;
    tipSplit = twoSplit;

    // llSetText("Truth & Beauty Beach, " + Name + " \nDonations Welcome!", <0.5,1.0,0.5>, 1.0);
    llInstantMessage(current, "You are now logged in.");
    llSetTimerEvent(checkInterval);
    getProfilePic(current);
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
    // Owner share percent
    linksetValue = llLinksetDataRead(SHARE_LSD_KEY);
    if (linksetValue != "") {
        tipSplit = (integer)linksetValue;
    } else {
        if (LoggedIn) {
            tipSplit = twoSplit;
        } else {
            tipSplit = oneSplit;
        }
    }
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
    linksetDataWrite(FRONT_LSD_KEY, (string)front_texture, "Front Side Texture");
    // Back face texture linkset data key
    linksetDataWrite(BACK_LSD_KEY, (string)back_texture, "Back Side Texture");
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
                llOwnerSay("The texture is missing or not a texture: " + txt);
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
        LoggedIn = FALSE;
        tipSplit = oneSplit;
        current = owner;
        Name = llKey2Name(current);
        getProfilePic(current);
        llSetTimerEvent(0.0);
    }
}

// TODO: fix hover text settings
setLoggedIn() {
    if (!LoggedIn) {
        current = toucher;
        Name = llKey2Name(current);
        LoggedIn = TRUE;
        tipSplit = twoSplit;
        getProfilePic(current);

        llSetText("🎧 DJ: " + Name + " 🎧\nTips Welcome!", <0.5,1.0,0.5>, 1.0);
        llInstantMessage(current, "You are now logged in as DJ.");
        llSetTimerEvent(checkInterval);
    } else if (toucher == current) {
        LoggedIn = FALSE;
        tipSplit = oneSplit;
        current = owner;
        Name = llKey2Name(current);
        getProfilePic(current);
        llSetText("🎶 Touch to Login as DJ 🎶", <1,1,1>, 1.0);
        llInstantMessage(toucher, "You have logged out.");
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

default {
    state_entry() {
        // Turn off touch to pay until we are ready to receive payments
        stopDonation();
        getDefaultTextures();
        toucher     = NULL_KEY;
        owner     = llGetOwner();

        // Retrieve any stored configuration or set defaults
        getDatastoreValues();

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

        sparkle();
        particles_on = TRUE;
        llSetTimerEvent(10);

        llRequestPermissions(owner, PERMISSION_DEBIT);
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                if (toucher == owner) {
                    current = owner;
                } else {
                    setLoggedIn();
                }
            } else {
                toucher = NULL_KEY;
            }
        } else {
            if (toucher != owner) {
                toucher = NULL_KEY;
            }
        }
    }

    run_time_permissions(integer perms) {
        // If Debit permissions are granted, set up the pay price for this single-price vendor
        if (perms & PERMISSION_DEBIT) {
            llSetClickAction(CLICK_ACTION_PAY);
            updateHoverText();
            llOwnerSay("Donation Board is ready and online.");
            readyForDonations(owner);
            startDonation();
            state donate;
        } else {
            llOwnerSay("⚠️ This script needs debit permissions to send money.");
            stopDonation();
            llMessageLinked(LINK_THIS, SND_LM_MENU, "", owner);
        }
    }

    link_message(integer sender, integer num, string message, key id) {
        if (ALL) {
            // Send the message to other boards in region with same owner listening on this channel
            if (message != "") {
                llRegionSay(objChannel, message);
            }
        }

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
            startDonation();
            state donate;
        } else if (num == RCV_LM_IDLE) {
            stopDonation();
            state idle;
        } else if (num == RCV_LM_INFO) {
            stateDonation();
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
        } else if (num == RCV_LM_HOVER) {
            updateHoverText();
        } else if (num == RCV_LM_PROFILE) {
            getProfilePic(current);
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

        if (!LoggedIn) return;

        checkGone(current);
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
        getDatastoreValues();
        setDatastoreValues();
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
        // Ensure only the owner or group members triggers the timer start check
        if (GROUP) {
            if ((llDetectedGroup(0)) || (toucher == owner)) {
                if (toucher == owner) {
                    llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
                } else {
                    setLoggedIn();
                }
                readyForDonations(current);
                startDonation();
            }
        } else {
            if (toucher == owner) {
                llMessageLinked(LINK_THIS, SND_LM_MENU, "", toucher);
            }
        }
    }

    link_message(integer sender, integer num, string message, key id) {
        if (ALL) {
            // Send the message to other boards in region with same owner listening on this channel
            if (message != "") {
                llRegionSay(objChannel, message);
            }
        }

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
            startDonation();
            state donate;
        } else if (num == RCV_LM_IDLE) {
            stopDonation();
            state idle;
        } else if (num == RCV_LM_INFO) {
            stateDonation();
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
            }
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

        if (!LoggedIn) return;

        checkGone(current);
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
        // Ensure only the owner or group members triggers the timer start check
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
        if (ALL) {
            // Send the message to other boards in region with same owner listening on this channel
            if (message != "") {
                llRegionSay(objChannel, message);
            }
        }

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
            startDonation();
            state donate;
        } else if (num == RCV_LM_IDLE) {
            stopDonation();
            state idle;
        } else if (num == RCV_LM_INFO) {
            stateDonation();
        } else if (num == RCV_LM_GROUP) {
            if (message == "Group") {
                GROUP = TRUE;
            } else if (message == "Owner") {
                GROUP = FALSE;
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
