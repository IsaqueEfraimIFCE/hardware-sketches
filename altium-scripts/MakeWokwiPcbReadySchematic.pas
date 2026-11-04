{..............................................................................}
{ MakeWokwiPcbReadySchematic - converts the Wokwi ESP32-C6 project into an    }
{ schematic. Parts: ESP32-C6 DevKitC-1, HX711 (load cell), MQ-7, MQ-4,         }
{ DS1307 RTC, SSD1306 OLED, microSD card, pushbutton, 4x 10k resistors.        }
{ Generic PCB footprint names are attached as component parameters. If your    }
{ installed libraries use different names, use Tools >> Footprint Manager to   }
{ remap them before updating the PCB.                                          }
{ Connectivity is made with net labels (same name = same net):                 }
{   VCC, GND, MQ4_OUT, MQ7_OUT, HX_DT, HX_SCK, BTN, SD_CS, SD_DI, SD_DO,       }
{   SD_SCK, SCL, SDA, TX, RX.                                                  }
{ Run in Altium: File >> Run Script, pick MakeWokwiPcbReadySchematic.          }
{..............................................................................}

Procedure AddComponentParameter(Component : ISch_Component; ParamName : String;
                                ParamValue : String; X, Y : Integer;
                                Hidden : Boolean);
Var
    Param : ISch_Parameter;
Begin
    Param := SchServer.SchObjectFactory(eParameter, eCreate_GlobalCopy);
    Param.Name     := ParamName;
    Param.Text     := ParamValue;
    Param.Location := Point(MilsToCoord(X), MilsToCoord(Y));
    Param.IsHidden := Hidden;
    Param.OwnerPartId          := 1;
    Param.OwnerPartDisplayMode := 0;
    Component.AddSchObject(Param);
End;

Function AddPart(SchDoc : ISch_Document; RefDes : String; Comment : String;
                 X : Integer; Y : Integer; Width : Integer;
                 LeftPins : TStringList; RightPins : TStringList;
                 Footprint : String) : ISch_Component;
Var
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
    i, H, N   : Integer;
    PinNo     : Integer;
Begin
    // X,Y = top-left corner of the body rectangle, in mils.
    // Pins are placed every 100 mils, 200 mils long.
    N := LeftPins.Count;
    If RightPins.Count > N Then N := RightPins.Count;
    H := (N + 1) * 100;

    Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    Component.Location             := Point(MilsToCoord(X), MilsToCoord(Y));
    Component.LibReference         := RefDes + '_WOKWI';
    Component.ComponentDescription := Comment;
    Component.CurrentPartID        := 1;
    Component.DisplayMode          := 0;

    Component.Designator.Text     := RefDes;
    Component.Designator.Location := Point(MilsToCoord(X), MilsToCoord(Y + 150));
    Component.Comment.Text        := Comment;
    Component.Comment.Location    := Point(MilsToCoord(X), MilsToCoord(Y + 25));

    AddComponentParameter(Component, 'Footprint', Footprint, X, Y - H - 150, False);
    AddComponentParameter(Component, 'PCB Footprint', Footprint, X, Y - H - 250, True);
    AddComponentParameter(Component, 'Value', Comment, X, Y - H - 350, True);

    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location  := Point(MilsToCoord(X), MilsToCoord(Y - H));
    R.Corner    := Point(MilsToCoord(X + Width), MilsToCoord(Y));
    R.LineWidth := eSmall;
    R.IsSolid   := True;
    R.OwnerPartId          := 1;
    R.OwnerPartDisplayMode := 0;
    Component.AddSchObject(R);

    PinNo := 0;
    For i := 0 To LeftPins.Count - 1 Do
    Begin
        PinNo := PinNo + 1;
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := IntToStr(PinNo);
        Pin.Name        := LeftPins[i];
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate180;   // extends left, hotspot at X - 200
        Pin.Location    := Point(MilsToCoord(X), MilsToCoord(Y - 100 * (i + 1)));
        Pin.PinLength   := MilsToCoord(200);
        Pin.ShowName       := True;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);
    End;

    For i := 0 To RightPins.Count - 1 Do
    Begin
        PinNo := PinNo + 1;
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := IntToStr(PinNo);
        Pin.Name        := RightPins[i];
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate0;     // extends right, hotspot at X + Width + 200
        Pin.Location    := Point(MilsToCoord(X + Width), MilsToCoord(Y - 100 * (i + 1)));
        Pin.PinLength   := MilsToCoord(200);
        Pin.ShowName       := True;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);
    End;

    SchDoc.RegisterSchObjectInContainer(Component);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Component.I_ObjectAddress);

    Result := Component;
End;

Procedure WireSeg(SchDoc : ISch_Document; X1, Y1, X2, Y2 : Integer);
Var
    Wire : ISch_Wire;
Begin
    Wire := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    Wire.Location     := Point(MilsToCoord(X1), MilsToCoord(Y1));
    Wire.InsertVertex := 1;
    Wire.SetState_Vertex(1, Point(MilsToCoord(X1), MilsToCoord(Y1)));
    Wire.InsertVertex := 2;
    Wire.SetState_Vertex(2, Point(MilsToCoord(X2), MilsToCoord(Y2)));
    SchDoc.RegisterSchObjectInContainer(Wire);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Wire.I_ObjectAddress);
End;

Procedure NetAt(SchDoc : ISch_Document; X, Y : Integer; Net : String);
Var
    NetLabel : ISch_NetLabel;
Begin
    NetLabel := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    NetLabel.Location    := Point(MilsToCoord(X), MilsToCoord(Y));
    NetLabel.Text        := Net;
    NetLabel.Orientation := eRotate0;
    SchDoc.RegisterSchObjectInContainer(NetLabel);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, NetLabel.I_ObjectAddress);
End;

// Horizontal stub off a pin hotspot + net label sitting on the wire.
// Dir = -1 for left-side pins, +1 for right-side pins.
Procedure StubH(SchDoc : ISch_Document; XPin, Y, Dir : Integer; Net : String);
Begin
    WireSeg(SchDoc, XPin, Y, XPin + Dir * 300, Y);
    If Dir < 0 Then
        NetAt(SchDoc, XPin - 300, Y, Net)
    Else
        NetAt(SchDoc, XPin + 50, Y, Net);
End;

// Vertical stub for resistor pins. Dir = +1 up, -1 down.
Procedure StubV(SchDoc : ISch_Document; X, YPin, Dir : Integer; Net : String);
Begin
    WireSeg(SchDoc, X, YPin, X, YPin + Dir * 200);
    NetAt(SchDoc, X, YPin + Dir * 200, Net);
End;

Function MakeResistorV(SchDoc : ISch_Document; RefDes : String; Value : String;
                       X : Integer; YTop : Integer; Footprint : String) : ISch_Component;
Var
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
Begin
    // Vertical resistor: pin 1 hotspot (X, YTop), pin 2 hotspot (X, YTop - 600)
    Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    Component.Location             := Point(MilsToCoord(X), MilsToCoord(YTop));
    Component.LibReference         := 'RES_WOKWI';
    Component.ComponentDescription := 'Resistor';
    Component.CurrentPartID        := 1;
    Component.DisplayMode          := 0;

    Component.Designator.Text     := RefDes;
    Component.Designator.Location := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 250));
    Component.Comment.Text        := Value;
    Component.Comment.Location    := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 400));

    AddComponentParameter(Component, 'Footprint', Footprint, X + 100, YTop - 550, False);
    AddComponentParameter(Component, 'PCB Footprint', Footprint, X + 100, YTop - 650, True);
    AddComponentParameter(Component, 'Value', Value, X + 100, YTop - 750, True);

    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location  := Point(MilsToCoord(X - 50), MilsToCoord(YTop - 450));
    R.Corner    := Point(MilsToCoord(X + 50), MilsToCoord(YTop - 150));
    R.LineWidth := eSmall;
    R.IsSolid   := True;
    R.OwnerPartId          := 1;
    R.OwnerPartDisplayMode := 0;
    Component.AddSchObject(R);

    Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    Pin.Designator  := '1';
    Pin.Name        := '1';
    Pin.Electrical  := eElectricPassive;
    Pin.Orientation := eRotate90;
    Pin.Location    := Point(MilsToCoord(X), MilsToCoord(YTop - 150));
    Pin.PinLength   := MilsToCoord(150);
    Pin.ShowName       := False;
    Pin.ShowDesignator := False;
    Pin.OwnerPartId          := 1;
    Pin.OwnerPartDisplayMode := 0;
    Component.AddSchObject(Pin);

    Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    Pin.Designator  := '2';
    Pin.Name        := '2';
    Pin.Electrical  := eElectricPassive;
    Pin.Orientation := eRotate270;
    Pin.Location    := Point(MilsToCoord(X), MilsToCoord(YTop - 450));
    Pin.PinLength   := MilsToCoord(150);
    Pin.ShowName       := False;
    Pin.ShowDesignator := False;
    Pin.OwnerPartId          := 1;
    Pin.OwnerPartDisplayMode := 0;
    Component.AddSchObject(Pin);

    SchDoc.RegisterSchObjectInContainer(Component);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Component.I_ObjectAddress);

    Result := Component;
End;

Procedure MakeWokwiPcbReadySchematic;
Var
    ServerDoc : IServerDocument;
    SchDoc    : ISch_Document;
    L, Rt     : TStringList;
    TextLabel : ISch_Label;
Begin
    Client.StartServer('SCH');
    If SchServer = Nil Then
    Begin
        ShowMessage('Schematic server not available.');
        Exit;
    End;

    ServerDoc := Client.OpenNewDocument('SCH', 'WokwiProject_PCBReady.SchDoc', 'WokwiProject_PCBReady.SchDoc', False);
    If ServerDoc = Nil Then
    Begin
        ShowMessage('Could not create a new schematic document.');
        Exit;
    End;
    Client.ShowDocument(ServerDoc);

    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then
        SchDoc := SchServer.GetSchDocumentByPath(ServerDoc.FileName);
    If SchDoc = Nil Then
    Begin
        ShowMessage('Schematic document was created but could not be accessed.');
        Exit;
    End;

    L  := TStringList.Create;
    Rt := TStringList.Create;

    SchServer.ProcessControl.PreProcess(SchDoc, '');
    Try
        // ------------------------------------------------------------------
        // U1: ESP32-C6 DevKitC-1  (body top-left 4200,7000, width 1200)
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        L.Add('5V');     // 6900 -> VCC
        L.Add('RST');    // 6800 -> GND (as in the Wokwi project)
        L.Add('TX');     // 6700 -> TX
        L.Add('RX');     // 6600 -> RX
        L.Add('GPIO2');  // 6500 -> MQ4_OUT
        L.Add('GPIO3');  // 6400 -> MQ7_OUT
        L.Add('GPIO4');  // 6300 -> HX_DT
        L.Add('GPIO5');  // 6200 -> HX_SCK
        L.Add('GPIO13'); // 6100 -> BTN
        L.Add('GND');    // 6000 -> GND
        Rt.Add('GPIO18'); // 6900 -> SD_CS
        Rt.Add('GPIO19'); // 6800 -> SD_DI
        Rt.Add('GPIO20'); // 6700 -> SD_DO
        Rt.Add('GPIO21'); // 6600 -> SD_SCK
        Rt.Add('GPIO22'); // 6500 -> SCL
        Rt.Add('GPIO23'); // 6400 -> SDA
        AddPart(SchDoc, 'U1', 'ESP32-C6-DevKitC-1', 4200, 7000, 1200, L, Rt, 'HDR_2x15_P2.54mm');

        StubH(SchDoc, 4000, 6900, -1, 'VCC');
        StubH(SchDoc, 4000, 6800, -1, 'GND');
        StubH(SchDoc, 4000, 6700, -1, 'TX');
        StubH(SchDoc, 4000, 6600, -1, 'RX');
        StubH(SchDoc, 4000, 6500, -1, 'MQ4_OUT');
        StubH(SchDoc, 4000, 6400, -1, 'MQ7_OUT');
        StubH(SchDoc, 4000, 6300, -1, 'HX_DT');
        StubH(SchDoc, 4000, 6200, -1, 'HX_SCK');
        StubH(SchDoc, 4000, 6100, -1, 'BTN');
        StubH(SchDoc, 4000, 6000, -1, 'GND');
        StubH(SchDoc, 5600, 6900,  1, 'SD_CS');
        StubH(SchDoc, 5600, 6800,  1, 'SD_DI');
        StubH(SchDoc, 5600, 6700,  1, 'SD_DO');
        StubH(SchDoc, 5600, 6600,  1, 'SD_SCK');
        StubH(SchDoc, 5600, 6500,  1, 'SCL');
        StubH(SchDoc, 5600, 6400,  1, 'SDA');

        // ------------------------------------------------------------------
        // U2: HX711 load cell amplifier (pins on the right, facing U1)
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        Rt.Add('VCC');   // 6900
        Rt.Add('DT');    // 6800
        Rt.Add('SCK');   // 6700
        Rt.Add('GND');   // 6600
        AddPart(SchDoc, 'U2', 'HX711 50kg', 800, 7000, 800, L, Rt, 'HDR_1x04_P2.54mm');
        StubH(SchDoc, 1800, 6900, 1, 'VCC');
        StubH(SchDoc, 1800, 6800, 1, 'HX_DT');
        StubH(SchDoc, 1800, 6700, 1, 'HX_SCK');
        StubH(SchDoc, 1800, 6600, 1, 'GND');

        // ------------------------------------------------------------------
        // U3: MQ-7 CO sensor
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        Rt.Add('VCC');   // 5800
        Rt.Add('OUT');   // 5700
        Rt.Add('GND');   // 5600
        AddPart(SchDoc, 'U3', 'MQ-7 CO sensor', 800, 5900, 800, L, Rt, 'HDR_1x04_P2.54mm');
        StubH(SchDoc, 1800, 5800, 1, 'VCC');
        StubH(SchDoc, 1800, 5700, 1, 'MQ7_OUT');
        StubH(SchDoc, 1800, 5600, 1, 'GND');

        // ------------------------------------------------------------------
        // U4: MQ-4 methane sensor
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        Rt.Add('VCC');   // 4800
        Rt.Add('OUT');   // 4700
        Rt.Add('GND');   // 4600
        AddPart(SchDoc, 'U4', 'MQ-4 CH4 sensor', 800, 4900, 800, L, Rt, 'HDR_1x04_P2.54mm');
        StubH(SchDoc, 1800, 4800, 1, 'VCC');
        StubH(SchDoc, 1800, 4700, 1, 'MQ4_OUT');
        StubH(SchDoc, 1800, 4600, 1, 'GND');

        // ------------------------------------------------------------------
        // SW1: pushbutton (GPIO13 to GND)
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        Rt.Add('1');     // 3800
        Rt.Add('2');     // 3700
        AddPart(SchDoc, 'SW1', 'Pushbutton', 800, 3900, 800, L, Rt, 'SW_PUSH_PTH_6x6mm');
        StubH(SchDoc, 1800, 3800, 1, 'BTN');
        StubH(SchDoc, 1800, 3700, 1, 'GND');

        // ------------------------------------------------------------------
        // U5: DS1307 RTC module (pins on the left, facing U1)
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        L.Add('5V');     // 6900
        L.Add('SCL');    // 6800
        L.Add('SDA');    // 6700
        L.Add('GND');    // 6600
        AddPart(SchDoc, 'U5', 'DS1307 RTC', 7600, 7000, 800, L, Rt, 'HDR_1x04_P2.54mm');
        StubH(SchDoc, 7400, 6900, -1, 'VCC');
        StubH(SchDoc, 7400, 6800, -1, 'SCL');
        StubH(SchDoc, 7400, 6700, -1, 'SDA');
        StubH(SchDoc, 7400, 6600, -1, 'GND');

        // ------------------------------------------------------------------
        // U6: SSD1306 OLED, I2C addr 0x3C
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        L.Add('VCC');    // 5800
        L.Add('SCL');    // 5700
        L.Add('SDA');    // 5600
        L.Add('GND');    // 5500
        AddPart(SchDoc, 'U6', 'SSD1306 OLED 0x3C', 7600, 5900, 800, L, Rt, 'HDR_1x04_P2.54mm');
        StubH(SchDoc, 7400, 5800, -1, 'VCC');
        StubH(SchDoc, 7400, 5700, -1, 'SCL');
        StubH(SchDoc, 7400, 5600, -1, 'SDA');
        StubH(SchDoc, 7400, 5500, -1, 'GND');

        // ------------------------------------------------------------------
        // U7: microSD card (SPI)
        // ------------------------------------------------------------------
        L.Clear;  Rt.Clear;
        L.Add('VCC');    // 4700
        L.Add('CS');     // 4600
        L.Add('DI');     // 4500
        L.Add('DO');     // 4400
        L.Add('SCK');    // 4300
        L.Add('GND');    // 4200
        AddPart(SchDoc, 'U7', 'microSD card', 7600, 4800, 800, L, Rt, 'HDR_1x06_P2.54mm');
        StubH(SchDoc, 7400, 4700, -1, 'VCC');
        StubH(SchDoc, 7400, 4600, -1, 'SD_CS');
        StubH(SchDoc, 7400, 4500, -1, 'SD_DI');
        StubH(SchDoc, 7400, 4400, -1, 'SD_DO');
        StubH(SchDoc, 7400, 4300, -1, 'SD_SCK');
        StubH(SchDoc, 7400, 4200, -1, 'GND');

        // ------------------------------------------------------------------
        // R1..R4: 10k pull-downs (as wired in the Wokwi project)
        //   R1: MQ4_OUT -> GND     R2: MQ7_OUT -> GND
        //   R3: SDA -> GND         R4: SCL -> GND
        // ------------------------------------------------------------------
        MakeResistorV(SchDoc, 'R1', '10k', 3400, 4800, 'RES_PTH_DIN0207_L6.3mm_P7.62mm');
        StubV(SchDoc, 3400, 4800,  1, 'MQ4_OUT');
        StubV(SchDoc, 3400, 4200, -1, 'GND');

        MakeResistorV(SchDoc, 'R2', '10k', 4200, 4800, 'RES_PTH_DIN0207_L6.3mm_P7.62mm');
        StubV(SchDoc, 4200, 4800,  1, 'MQ7_OUT');
        StubV(SchDoc, 4200, 4200, -1, 'GND');

        MakeResistorV(SchDoc, 'R3', '10k', 5000, 4800, 'RES_PTH_DIN0207_L6.3mm_P7.62mm');
        StubV(SchDoc, 5000, 4800,  1, 'SDA');
        StubV(SchDoc, 5000, 4200, -1, 'GND');

        MakeResistorV(SchDoc, 'R4', '10k', 5800, 4800, 'RES_PTH_DIN0207_L6.3mm_P7.62mm');
        StubV(SchDoc, 5800, 4800,  1, 'SCL');
        StubV(SchDoc, 5800, 4200, -1, 'GND');

        // ------------------------------------------------------------------
        // Title
        // ------------------------------------------------------------------
        TextLabel := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
        TextLabel.Location := Point(MilsToCoord(800), MilsToCoord(7500));
        TextLabel.Text     := 'PCB-ready Wokwi project: generic headers/modules + PTH resistors';
        SchDoc.RegisterSchObjectInContainer(TextLabel);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, TextLabel.I_ObjectAddress);

    Finally
        SchServer.ProcessControl.PostProcess(SchDoc, '');
        L.Free;
        Rt.Free;
    End;

    SchDoc.GraphicallyInvalidate;
    Client.SendMessage('SCH:ZoomAllObjects', '', 255, Client.CurrentView);
End;
