// DonationBoard LSL script to accept donation payments
// Created by Missy Restless <missyrestless@gmail.com>

key current;
string Name = "";
integer LoggedIn = FALSE;
float maxTime = 3600.0;
float checkInterval = 30.0;
float maxDistance = 15.0;

string fallbackTexture = "Default_Texture"; // Name of your fallback texture
string VERT_SPACE = "\n \n \n \n \n ";

string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

list sides;
list deftextures;
key lastRequestID;

integer tipSplit = 100; // % given to owner (default 100)
key setupUser;

key owner;
string ownerName;

integer dialogChannel = -999;
integer dialogHandle;

list tipNames;
list tipAmounts;

integer totalDonations = 0;

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

ReadyForDonations(key recKey) {
    current = recKey;
    Name = llKey2Name(current);
    LoggedIn = TRUE;

    // llSetText("Truth & Beauty Beach, " + Name + " \nDonations Welcome!", <0.5,1.0,0.5>, 1.0);
    llInstantMessage(current, "You are now logged in.");
    llSetTimerEvent(checkInterval);
    GetProfilePic(current);
}

default
{
    state_entry() {
        // Turn off pay options until we are ready to receive payments
        llSetPayPrice(PAY_HIDE, [PAY_HIDE ,PAY_HIDE, PAY_HIDE, PAY_HIDE]);
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        GetDefaultTextures();
        owner = llGetOwner();
        ownerName = llKey2Name(owner);
        // Remove any previous hover text
        llSetText("", < 1.0, 1.0, 1.0>, 1.0);

        llRequestPermissions(owner, PERMISSION_DEBIT);
    }

    run_time_permissions(integer perms) {
        // If Debit permissions are granted, set up the pay price for this single-price vendor
        if (perms & PERMISSION_DEBIT) {
            llSetPayPrice(250, [100, 250, 500, 1000]);
            updateHoverText();
            llOwnerSay("Donation Board is ready and online.");
            ReadyForDonations(owner);
        } else {
            llOwnerSay("⚠️ This script needs debit permissions to send money.");
        }
    }

    money(key id, integer amount) {
        // if (!LoggedIn || id == current) return;

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

    on_rez(integer start_param) { llResetScript(); }
}
