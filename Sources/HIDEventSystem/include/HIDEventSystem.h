#include <IOKit/hid/IOHIDUsageTables.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>

// Private event-system constructor used for dynamic per-device pointer
// properties. The public simple client can read and write acceleration but
// does not hold HIDPointerResolution while it is active.
CF_IMPLICIT_BRIDGING_ENABLED
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
CF_IMPLICIT_BRIDGING_DISABLED
