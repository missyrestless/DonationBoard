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
//                                                //
////////////////////////////////////////////////////

string   VERSION = "1.0.1";

integer  relayStatus   = TRUE;  // TRUE if the Stream Relay is active, FALSE if not
integer  showHoverText = FALSE;
integer  debug         = FALSE;
integer  relayListenID;
integer  relayChannel;           // Channel for communication between screens, based on owner
 

key      owner;
key      toucher = NULL_KEY;

string   DEF_STREAM_URL = "http://server1.chilltrax.com:9000";
string   VERT_SPACE     = "\n \n \n \n \n \n ";
string   relaySlurl;
string   parcelName;

vector currentPos;

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

stateRelay() {
    string msg = "The Truth & Beauty Stream Relay on parcel " + parcelName + " at " + relaySlurl + " is: ";
    if (relayStatus) {
        msg += "Enabled and Active";
    } else {
        msg += "Disabled and Inactive";
    }
    llOwnerSay(msg);
}

updateHoverText() {
    string text = "Stream URL: " + llGetParcelMusicURL() + "\n";
    vector color;

    if (relayStatus) {
        color = <0.0, 1.0, 0.0>; // Green hover text
    } else {
        text += "Inactive, temporarily unavailable";
        color = <1.0, 1.0, 0.0>; // Yellow hover text
    }
    text += VERT_SPACE;
    llSetText(text, color, 1.0);
}

string getParcelName() {
    list details = llGetParcelDetails(currentPos, [PARCEL_DETAILS_NAME]);
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
    list   details  = llGetParcelDetails(currentPos, [PARCEL_DETAILS_OWNER, PARCEL_DETAILS_GROUP]);
    key    ownerKey = llList2Key(details, 0);
    key    groupKey = llList2Key(details, 1);

    // If the parcel is group-owned, the owner key and group key are identical
    if ((ownerKey == groupKey) && (groupKey != NULL_KEY)) {
        llOwnerSay("OK: parcel is deeded to Group: " + "secondlife:///app/group/" + (string)groupKey + "/about");
        return TRUE;
    } else {
        llOwnerSay("WARNING: parcel is privately owned and not deeded to a group.");
        return FALSE;
    }
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

        relaySlurl = getRelaySlurl();
        parcelName = getParcelName();
        currentPos = llGetPos();

         // Get the parcel details at the object's current position
        list details = llGetParcelDetails(currentPos, [PARCEL_DETAILS_ID]);
        // Extract the parcel key (ID) from the list
        key parcelID = llList2Key(details, 0);

        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);

        // Compute a large negative channel number based on the parcel ID
        // Donation boards will use this channel to send the stream URL
        relayChannel = 0x80000000 | (integer) ( "0x" + (string) parcelID );
        llListenRemove(relayListenID);
        relayListenID = llListen(relayChannel, "", NULL_KEY, "");
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
            } else if (cmd == "relay start") {
                relayStatus = TRUE;
            } else if (cmd == "relay info") {
                stateRelay();
            } else {
                if (relayStatus) setStreamURL(message);
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
        // Check if relay has been deeded to a group
        if (chkOwner()) {
            key groupKey = llGetOwner();
            llOwnerSay("Deed the Truth & Beauty Stream Relay to the Group: " + "secondlife:///app/group/" + (string)groupKey + "/about");
        } else {
            llOwnerSay("The Truth & Beauty Stream Relay is only required on parcels that have been deeded to a group");
            llOwnerSay("If this parcel is going to remain privately owned then you can delete the relay object");
            llOwnerSay("If the parcel is deeded to a group, re-rez or reset the Stream Relay object");
            llOwnerSay("Once the parcel is group owned, deed the Truth & Beauty Stream Relay to the same group that is this parcel owner");
        }

        llResetScript();
    }
}
