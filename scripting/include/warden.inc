#if defined _warden_included
  #endinput
#endif
#define _warden_included

/**
 * Checks if any warden exist
 *
 * @return True if warden exists, false if vice versa
 */
native bool warden_exist();

/**
 * Checks if client is a warden
 *
 * @param iClient The client to run the check on
 * @return True if client is a warden, false if vice versa
 */
native bool warden_iswarden(int iClient);

/**
 * Sets a client as warden
 *
 * @param iClient The client to set as warden
 */
native void warden_set(int iClient);

/**
 * Removes the current warden if exists
 *
 * @param iClient The warden client to remove
 */
native void warden_remove(int iClient);

/**
 * Called when client becomes a warden
 *
 * @param iClient The new client warden
 */
forward void warden_OnWardenCreation(int iClient);

/**
 * Called when client is no longer a warden
 *
 * @param iClient The client who is no longer warden
 */
forward void warden_OnWardenRemoved(int iClient);