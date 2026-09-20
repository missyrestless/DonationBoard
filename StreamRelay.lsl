////////////////////////////////////////////////////
//     Parcel Music Stream Relay LSL Script       //
//                                                //
//   Listens on private channel for Music URL     //
//   Must be deeded to group on group owned land  //
////////////////////////////////////////////////////

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
// 2026-Sep-18 Created                            //
// 2026-Sep-20 Initial working version released   //
//                                                //
////////////////////////////////////////////////////

string   VERSION = "1.1.0";

integer  relayStatus   = TRUE;  // TRUE if the Stream Relay is active, FALSE if not
integer  showHoverText = FALSE;
integer  debug         = FALSE;
integer  deeded        = FALSE; // TRUE if parcel is deeded to a group
integer  relayListenID;
integer  relayChannel;          // Channel for communication between screens, based on owner
 
key      groupKey;
key      ownerKey;
key      owner;
key      toucher = NULL_KEY;

list     details;

string   DEF_STREAM_URL = "http://server1.chilltrax.com:9000";
string   VERT_SPACE     = "\n \n \n \n \n \n ";
string   groupName;
string   parcelName;
string   relaySlurl;

vector currentPos;

stateRelay() {
    string msg = "The Truth & Beauty Stream Relay version " + VERSION;
    msg       += " on parcel " + parcelName + " at " + relaySlurl + " is: ";
    if (relayStatus) {
        msg += "\nEnabled and Active";
    } else {
        msg += "\nDisabled and Inactive";
    }
    llOwnerSay(msg);
    if (chkOwner()) {
        msg = "Parcel " + parcelName + " is deeded to group: " + groupName;
    } else {
        msg = "Parcel " + parcelName + " is privately owned";
    }
    llOwnerSay(msg);
}

updateHoverText() {
    string text = parcelName + " Stream URL\n" + llGetParcelMusicURL() + "\n";
    vector color;

    if (relayStatus) {
        color = <0.0, 1.0, 0.0>; // Green hover text
    } else {
        text += "Inactive, temporarily unavailable";
        color = <1.0, 1.0, 0.0>; // Yellow hover text
    }
    text += VERT_SPACE;
    if (showHoverText) {
        llSetText(text, color, 1.0);
    } else {
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);
    }
}

string getParcelName() {
    details = llGetParcelDetails(currentPos, [PARCEL_DETAILS_NAME]);
    return llList2String(details, 0);
}

string getRelaySlurl() {
    string regionName = llGetRegionName();

    // Round coordinates to whole integers
    integer x = (integer)currentPos.x;
    integer y = (integer)currentPos.y;
    integer z = (integer)currentPos.z;
    string coords = (string)x + "/" + (string)y + "/" + (string)z;

    // Return the constructed Slurl, escape region name as it may have spaces
    return "https://maps.secondlife.com/secondlife/" + llEscapeURL(regionName) + "/" + coords;
}

integer chkOwner() {
    // If the parcel is group-owned, the owner key and group key are identical
    if ((ownerKey == groupKey) && (groupKey != NULL_KEY)) {
        llOwnerSay("OK: parcel is deeded to Group: " + groupName);
        deeded = TRUE;
    } else {
        llOwnerSay("WARNING: parcel is privately owned and not deeded to a group.");
        deeded = FALSE;
    }
    return deeded;
}

integer isValidURL(string url) {
    // Clean up any leading/trailing spaces
    url = llStringTrim(url, STRING_TRIM);

    string lower_url = llToLower(url);
    integer index = -1;

    // 1. Check for valid protocol prefix
    if (llSubStringIndex(lower_url, "https://") == 0) {
        index = 8; // Protocol length
    } else if (llSubStringIndex(lower_url, "http://") == 0) {
        index = 7; // Protocol length
    } else {
        return FALSE; // No valid http/https prefix found
    }

    // 2. Ensure there is content after the protocol prefix
    if (llStringLength(url) <= index) {
        return FALSE;
    }

    // 3. Reject URLs that contain spaces (invalid format)
    if (llSubStringIndex(url, " ") != -1) {
        return FALSE;
    }

    // 4. Basic domain structure check: look for a dot '.' after the protocol prefix
    string remaining = llDeleteSubString(url, 0, index - 1);
    if (llSubStringIndex(remaining, ".") == -1) {
        return FALSE; // No domain extension separator found
    }

    return TRUE;
}

setGroupName() {
    currentPos = llGetPos();
    details    = llGetParcelDetails(currentPos, [PARCEL_DETAILS_OWNER, PARCEL_DETAILS_GROUP]);
    ownerKey   = llList2Key(details, 0);
    groupKey   = llList2Key(details, 1);
    groupName  = "secondlife:///app/group/" + (string)groupKey + "/about";
}

setStreamURL(string url) {
    if (llGetParcelMusicURL() != url) {
        if (isValidURL(url)) {
            llSetParcelMusicURL(url);
        }
    }
}

default {
    state_entry() {
        toucher   = NULL_KEY;

        // Sets global variables
        setGroupName();

        relaySlurl = getRelaySlurl();
        parcelName = getParcelName();

        // Check if relay needs to be deeded to a group
        if (chkOwner()) {
            llOwnerSay("Deed the Truth & Beauty Stream Relay to the Group: " + groupName);
        } else {
            llOwnerSay("The Truth & Beauty Stream Relay is only required on parcels that have been deeded to a group");
            llOwnerSay("If this parcel is going to remain privately owned then you can delete the relay object");
            llOwnerSay("If the parcel is deeded to a group, re-rez or reset the Stream Relay object");
            llOwnerSay("Once the parcel is group owned, deed the Truth & Beauty Stream Relay to the same group that is this parcel owner");
        }

        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);

        // 1. Retrieve the parcel ID (UUID key) for the object's current position
        list details = llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_ID]);
        key parcelID = llList2Key(details, 0);

        // 2. Extract an 8-character hex block (e.g., the first 8 characters)
        string hexPart = llGetSubString((string)parcelID, 0, 7);

        // 3. Convert the hex string to an integer and force it negative
        // Adding "0x" allows LSL to implicitly typecast the hex string to an integer.
        // Bitwise OR with 0x80000000 sets the sign bit, forcing a large negative range.
        relayChannel = 0x80000000 | (integer)("0x" + hexPart);

        llListenRemove(relayListenID);
        if (deeded) {
            relayListenID = llListen(relayChannel, "", NULL_KEY, "");
        } else {
            llOwnerSay("Truth & Beauty Stream Relay is Disabled on privately owned parcel");
        }
    }

    touch_start(integer num_detected) {
        toucher = llDetectedKey(0);
        if ((llDetectedGroup(0)) || (toucher == owner)) {
            showHoverText = !showHoverText;
            updateHoverText();
        } else {
            toucher = NULL_KEY;
        }
    }

    listen(integer channel, string name, key id, string message) {
        string cmd = llToLower(message);

        if (channel == relayChannel) {
            if (cmd == "relay stop") {
                relayStatus = FALSE;
                updateHoverText();
            } else if (cmd == "relay start") {
                relayStatus = TRUE;
                updateHoverText();
            } else if (cmd == "relay info") {
                stateRelay();
            } else if (relayStatus) {
                setStreamURL(message);
            }
        }
    }

    changed(integer change) {
        // Check if the change event was caused by an owner change
        if ((change & CHANGED_OWNER) || (change & CHANGED_INVENTORY)) {
            llResetScript();
        }
    }

    on_rez(integer num) {
        llResetScript();
    }
}
