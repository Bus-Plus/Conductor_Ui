# BusTrackPlus Conductor App UML Diagrams

These UML diagrams are derived from the current codebase:
- `lib/main.dart`
- `lib/screens/conductor_login_page.dart`
- `lib/screens/conductor_home_page.dart`
- `lib/screens/issue_ticket_page.dart`
- `lib/validate.dart`
- `lib/nfc_reader_page.dart`
- `lib/status_page.dart`

## 1. Use Case Diagram

```mermaid
flowchart LR
    actorConductor[Conductor]
    actorFirestore[(Firebase Firestore)]
    actorQr[QR Scanner]
    actorNfc[NFC/USB Scanner]

    subgraph App[Bus Tracking Conductor App]
        UC1([Login with Route + Bus Number])
        UC2([Initialize Bus Session])
        UC3([View Current Stop])
        UC4([Move to Next Stop])
        UC5([Issue Ticket - Non Pass])
        UC6([Issue Ticket - Pass via QR])
        UC7([Issue Ticket - Pass via NFC/USB])
        UC8([Validate Pass and Expiry])
        UC9([Reset Trip])
        UC10([Logout and Delete Bus Session])
        UC11([Monitor Firebase Connectivity])
    end

    actorConductor --> UC1
    actorConductor --> UC3
    actorConductor --> UC4
    actorConductor --> UC5
    actorConductor --> UC6
    actorConductor --> UC7
    actorConductor --> UC9
    actorConductor --> UC10

    UC1 --> UC2
    UC6 --> UC8
    UC7 --> UC8

    UC2 <--> actorFirestore
    UC3 <--> actorFirestore
    UC4 <--> actorFirestore
    UC5 <--> actorFirestore
    UC8 <--> actorFirestore
    UC9 <--> actorFirestore
    UC10 <--> actorFirestore
    UC11 <--> actorFirestore

    UC6 <--> actorQr
    UC7 <--> actorNfc
```

## 2. Class Diagram (Application Classes)

```mermaid
classDiagram
    class MyAppEntry {
        +main()
        +Firebase.initializeApp()
    }

    class ConductorLoginPage {
        <<StatefulWidget>>
    }

    class _ConductorLoginPageState {
        -List~String~ busRoutes
        -String? selectedRoute
        -bool isLoading
        -TextEditingController transportNumberController
        +initState()
        +fetchBusRoutes() Future~void~
        +initializeBusStatus(selectedRoute, transportNumber) Future~void~
        +handleLogin() void
        +build(context) Widget
        +dispose() void
    }

    class ConductorHomePage {
        <<StatefulWidget>>
        +String busNumber
        +String routeId
    }

    class _ConductorHomePageState {
        -List~String~ stops
        -int currentStopIndex
        -bool isLoading
        -bool isOnline
        +currentStop String
        +initState()
        +monitorConnection() void
        +fetchStops() Future~void~
        +_nextStop() void
        +_resetTrip() void
        +_deleteTransportDocument() Future~void~
        +_issueTicket() void
        +build(context) Widget
    }

    class IssueTicketPage {
        <<StatefulWidget>>
        +String busNumber
        +String routeId
        +List~String~ stops
    }

    class _IssueTicketPageState {
        -String? destination
        -String? selectedPaymentMethod
        -String? selectedPassType
        -List~String~ passTypes
        -String? username
        -Map~String,dynamic~? passData
        -int currentStopIndex
        +initState()
        +scanViaNFC() Future~void~
        +fetchPassTypes() Future~void~
        +fetchCurrentStop() Future~void~
        +isUserIdExistsInPassType(userId, passType) Future~bool~
        +validatePass() Future~void~
        +openValidatePageAndScan() Future~void~
        +issueTicket() Future~void~
        +showMessage(message) void
        +build(context) Widget
    }

    class ValidatePage {
        <<StatefulWidget>>
    }

    class _ValidatePageState {
        -MobileScannerController controller
        +_onDetect(capture) void
        +dispose() void
        +build(context) Widget
    }

    class NFCReaderPage {
        <<StatefulWidget>>
    }

    class _NFCReaderPageState {
        -UsbPort? port
        -StreamSubscription~Uint8List~? _usbSub
        -bool isScanningUsb
        -bool isScanningNfc
        -String message
        +startCardScan() Future~void~
        +startNativeNfcScan() Future~void~
        +dispose() void
        +build(context) Widget
    }

    class StatusPage {
        <<StatefulWidget>>
    }

    class _StatusPageState {
        -List~String~ stops
        -List~dynamic~ passengerCount
        -int currentStopIndex
        -bool isLoading
        +initState()
        +fetchStatusData() Future~void~
        +build(context) Widget
    }

    ConductorLoginPage --> _ConductorLoginPageState
    ConductorHomePage --> _ConductorHomePageState
    IssueTicketPage --> _IssueTicketPageState
    ValidatePage --> _ValidatePageState
    NFCReaderPage --> _NFCReaderPageState
    StatusPage --> _StatusPageState

    _ConductorLoginPageState ..> ConductorHomePage : Navigator.push
    _ConductorHomePageState ..> IssueTicketPage : Navigator.push
    _IssueTicketPageState ..> ValidatePage : Navigator.push
```

## 3. Component Diagram

```mermaid
flowchart TB
    subgraph FlutterClient[Flutter Client]
        Main[main.dart]
        Login[ConductorLoginPage]
        Home[ConductorHomePage]
        Ticket[IssueTicketPage]
        QR[ValidatePage]
        NFC[NFCReaderPage]
        Legacy[StatusPage Legacy]
    end

    subgraph Firebase[Firebase]
        AuthInit[Firebase Core Init]
        FS[(Cloud Firestore)]
    end

    subgraph DeviceIO[Device and Plugins]
        MobileScanner[mobile_scanner]
        UsbSerial[usb_serial]
        NativeNfc[flutter_nfc_kit]
    end

    Main --> AuthInit
    Main --> Login

    Login <--> FS
    Login --> Home

    Home <--> FS
    Home --> Ticket

    Ticket <--> FS
    Ticket --> QR
    QR --> MobileScanner

    Ticket --> UsbSerial
    NFC --> UsbSerial
    NFC --> NativeNfc

    Legacy <--> FS
```

## 4. Sequence Diagram - Login and Bus Session Initialization

```mermaid
sequenceDiagram
    actor Conductor
    participant LoginUI as ConductorLoginPage
    participant Firestore as Cloud Firestore
    participant HomeUI as ConductorHomePage

    Conductor->>LoginUI: Open app
    LoginUI->>Firestore: get bus_status collection docs
    Firestore-->>LoginUI: route IDs

    Conductor->>LoginUI: Select route + enter 4-digit bus number
    Conductor->>LoginUI: Tap Login

    LoginUI->>Firestore: get bus_status/{routeId}
    alt route doc not exists
        LoginUI->>Firestore: set bus_status/{routeId}{createdAt}
    end

    LoginUI->>Firestore: get bus_stops/{routeId}
    Firestore-->>LoginUI: stops list

    LoginUI->>Firestore: get bus_status/{routeId}/busses/{busNumber}
    alt bus doc not exists
        LoginUI->>Firestore: set busses/{busNumber}{currentStop:0, stops:[0..n]}
    end

    LoginUI->>HomeUI: Navigator.push(routeId, busNumber)
```

## 5. Sequence Diagram - Issue Ticket (Cash/Non-Pass)

```mermaid
sequenceDiagram
    actor Conductor
    participant HomeUI as ConductorHomePage
    participant TicketUI as IssueTicketPage
    participant Firestore as Cloud Firestore

    Conductor->>HomeUI: Tap Issue Ticket
    HomeUI->>TicketUI: Open with stops, routeId, busNumber

    TicketUI->>Firestore: get payment_methods/passes
    TicketUI->>Firestore: get bus_status/{routeId}/busses/{busNumber}

    Conductor->>TicketUI: Select payment method != passes
    Conductor->>TicketUI: Select destination
    Conductor->>TicketUI: Tap Issue Ticket

    TicketUI->>Firestore: get bus_status/{routeId}/busses/{busNumber}
    Firestore-->>TicketUI: currentStop + stops[]

    TicketUI->>TicketUI: validate destination index and direction
    TicketUI->>TicketUI: increment stops[currentStop..destination]
    TicketUI->>Firestore: update stops[]

    Firestore-->>TicketUI: success
    TicketUI-->>Conductor: Show "Ticket Issued"
    TicketUI->>HomeUI: Navigator.pop()
```

## 6. Sequence Diagram - Issue Ticket (Pass via QR/NFC)

```mermaid
sequenceDiagram
    actor Conductor
    participant TicketUI as IssueTicketPage
    participant QRUI as ValidatePage
    participant NFC as USB/NFC Scanner
    participant Firestore as Cloud Firestore

    Conductor->>TicketUI: Select payment method = passes
    Conductor->>TicketUI: Select pass type

    alt QR path
        Conductor->>TicketUI: Tap Scan QR
        TicketUI->>QRUI: Open scanner
        QRUI-->>TicketUI: Return scanned userId
    else NFC/USB path
        Conductor->>TicketUI: Tap Card
        TicketUI->>NFC: Send READ command
        NFC-->>TicketUI: Return scanned userId
    end

    TicketUI->>Firestore: get passes/{passType}/{passType}/{userId}
    alt pass not found
        TicketUI-->>Conductor: Show invalid pass
    else pass found
        TicketUI->>TicketUI: validate validTill date
        alt expired
            TicketUI-->>Conductor: Show pass expired
        else valid
            alt pass has toStop
                TicketUI->>TicketUI: use toStop as destination
            else no toStop
                Conductor->>TicketUI: select destination manually
            end

            TicketUI->>Firestore: get bus_status/{routeId}/busses/{busNumber}
            TicketUI->>TicketUI: increment stops[currentStop..destination]
            TicketUI->>Firestore: update stops[]
            TicketUI-->>Conductor: Show "Ticket Issued"
        end
    end
```

## 7. Activity Diagram - End-to-End Conductor Workflow

```mermaid
flowchart TD
    A([Start App]) --> B[Initialize Firebase]
    B --> C[Open ConductorLoginPage]
    C --> D[Fetch route IDs from bus_status]
    D --> E{Route selected?}
    E -- No --> E1[Show error] --> C
    E -- Yes --> F{4-digit bus number valid?}
    F -- No --> F1[Show error] --> C
    F -- Yes --> G[Initialize bus session docs]
    G --> H[Open ConductorHomePage]

    H --> I[Fetch stops + currentStop]
    I --> J{Action?}

    J -->|Next Stop| K[Increment currentStop in Firestore]
    K --> J

    J -->|Reset Trip| L[Set currentStop=0 and reset stops[]]
    L --> J

    J -->|Issue Ticket| M[Open IssueTicketPage]
    M --> N{Payment method}

    N -->|Non-pass| O[Select destination]
    O --> P[Issue ticket and update stops[]]
    P --> J

    N -->|Passes| Q[Select pass type]
    Q --> R{Scan source}
    R -->|QR| S[Scan via ValidatePage]
    R -->|NFC/USB| T[Scan card]
    S --> U[Validate pass in Firestore]
    T --> U

    U --> V{Pass valid and not expired?}
    V -- No --> V1[Show error] --> M
    V -- Yes --> W{toStop available?}
    W -- Yes --> X[Auto destination = toStop]
    W -- No --> Y[Select destination manually]
    X --> P
    Y --> P

    J -->|Logout| Z[Delete bus session doc]
    Z --> AA([End])
```

## 8. State Machine Diagram - Bus Session State

```mermaid
stateDiagram-v2
    [*] --> NotLoggedIn
    NotLoggedIn --> SessionInitialized : Login success

    SessionInitialized --> AtStop : fetch currentStop
    AtStop --> AtStop : Next Stop
    AtStop --> Ticketing : Open IssueTicketPage
    Ticketing --> AtStop : Ticket issued or back
    AtStop --> TripReset : Reset Trip
    TripReset --> AtStop : currentStop=0, stops[]=0

    AtStop --> NotLoggedIn : Logout + delete bus doc
    Ticketing --> NotLoggedIn : Logout from home after return
```

## 9. Firestore Data Model Diagram (UML-style)

```mermaid
classDiagram
    class BusStatusRoute {
      +String routeId (docId)
      +Timestamp createdAt?
    }

    class BusStatusBus {
      +String busNumber (docId)
      +int currentStop
      +List~int~ stops
    }

    class BusStops {
      +String routeId (docId)
      +List~String~ stops
    }

    class PaymentMethodsPasses {
      +String docId = passes
      +List~String~ type
    }

    class PassRecord {
      +String passType (docId)
      +String userId (docId)
      +String validTill (dd-MM-yyyy)
      +String toStop?
    }

    BusStatusRoute "1" --> "*" BusStatusBus : subcollection busses
    BusStatusRoute "1" --> "1" BusStops : routeId mapping
    PaymentMethodsPasses "1" --> "*" PassRecord : by pass type and userId
```

## Notes on Code Alignment

- Primary active flow is `main.dart -> ConductorLoginPage -> ConductorHomePage -> IssueTicketPage`.
- `ValidatePage` is used by pass QR flow.
- `NFCReaderPage` exists as a standalone scanner utility screen, while `IssueTicketPage` also performs USB scan directly.
- `StatusPage` uses a legacy schema (`bus_stops/list` and `bus_status/current`) and is not part of the main navigation path.
