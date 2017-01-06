//
//  MapViewController.m
//  ObjCDemo
//
//  Created by Evgen Bodunov on 11/15/16.
//  Copyright © 2016 GetYourMap. All rights reserved.
//

#import <GLMap/GLMap.h>
#import <CoreLocation/CoreLocation.h>

#import "MapViewController.h"
#import "DownloadMapsViewController.h"
#import "ViewController.h"
#import "OSMTileSource.h"

@interface Pin : NSObject
@property (assign) GLMapPoint pos;
@property (assign) int imageID;
@end

@implementation Pin
@end

@implementation MapViewController {
    UIButton *_downloadButton;
    
    GLMapView *_mapView;
    GLMapImage *_mapImage;
    GLMapInfo *_mapToDownload;
    BOOL _flashAdd;
    
    CLLocationManager *_locationManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Demo map";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownloadButtonText:) name:kGLMapInfoDownloadProgress object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapDownloaded:) name:kGLMapInfoDownloadFinished object:nil];
    
    _mapView = [[GLMapView alloc] initWithFrame:self.view.bounds];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview: _mapView];
    
    _locationManager = [[CLLocationManager alloc] init];
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        [_locationManager requestWhenInUseAuthorization];
    }
    //In order to show user location using GLMapView you should create your own CLLocationManager and set GLMapView as CLLocationManager's delegate. Or you could forward `-locationManager:didUpdateLocations:` calls from your location manager delegate to the GLMapView.
    _locationManager.delegate = _mapView;
    [_locationManager startUpdatingLocation];
    [_mapView setShowUserLocation:YES];
    
    _downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _downloadButton.backgroundColor = [UIColor lightTextColor];
    [_downloadButton addTarget:self action:@selector(downloadButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    
    _downloadButton.frame = CGRectMake(0, 0, 220, 30);
    _downloadButton.center = self.view.center;
    _downloadButton.hidden = YES;
    
    [self.view addSubview:_downloadButton];
    
    //_downloadButton.hidden = YES;
    [self updateDownloadButton];
    // Map list is updated, because download button depends on available map list and during first launch this list is empty
    [[GLMapManager sharedManager] updateMapListWithCompletionBlock:nil];
    
    __weak MapViewController *wself = self;
    _mapView.centerTileStateChangedBlock = ^{
        [wself updateDownloadButton];
    };
    
    _mapView.mapDidMoveBlock = ^(GLMapBBox bbox) {
        [wself updateDownloadButtonText:nil];
    };
    
    int scenario = _demoScenario.intValue;
    switch (scenario) {
        case Test_OfflineMap: // open map
            // nothing to do. just start rendering inside viewWillAppear
            break;
        case Test_EmbeddMap: // load map from app resources
            [self loadEmbedMap];
            break;
        case Test_OnlineMap:
            [GLMapManager sharedManager].tileDownloadingAllowed = YES;
            
            // Move map to the San Francisco
            [_mapView moveTo:GLMapGeoPointMake(37.3257, -122.0353) zoomLevel:14];
            break;
        case Test_RasterOnlineMap:
        {
            [_mapView setRasterSources:@[[[OSMTileSource alloc] init]]];
            break;
        }
        case Test_ZoomToBBox: // zoom to bbox
            [self zoomToBBox];
            break;
        case Test_Notifications:
            [self testNotifications];
            break;
        case Test_SingleImage: // add/remove image
        {
            // we'll just add button for this demo
            UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithTitle:@"Add image" style:UIBarButtonItemStylePlain target:self action:@selector(addImage:)];
            self.navigationItem.rightBarButtonItem = barButton;
            
            [self addImage:barButton];
            break;
        }
        case Test_MultiImage: // add pin from navigation item, remove by tap on pin
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"Long tap on map to add pin, tap on pin to remove it" preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            }]];
            
            [self presentViewController:alert animated:YES completion:nil];
            
            [self setupPinGestures];
            break;
        }
        case Test_Markers:
            [self addMarkers];
            break;
        case Test_MarkersWithClustering:
            [self addMarkersWithClustering];
            break;
        case Test_MultiLine:
            [self addMultiline];
            break;
        case Test_Polygon:
            [self addPolygon];
            break;
        case Test_GeoJSON:
            [self loadGeoJSON];
            break;
        case Test_Screenshot:
        {
            NSLog(@"Start capturing frame");
            [_mapView captureFrameWhenFinish:^(UIImage *img) { // completion handler called in main thread
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:@"Image captured %p\n %.0fx%.0f\nscale %.0f", img, img.size.width, img.size.height, img.scale] preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];
                
                [self presentViewController:alert animated:YES completion:nil];
            }];
            break;
        }
        case Test_FlyTo:
        {
            // we'll just add button for this demo
            UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithTitle:@"Fly" style:UIBarButtonItemStylePlain target:self action:@selector(flyTo:)];
            self.navigationItem.rightBarButtonItem = barButton;
            
            // Move map to the San Francisco
            [_mapView flyTo:GLMapGeoPointMake(37.3257, -122.0353) zoomLevel:14];
            [GLMapManager sharedManager].tileDownloadingAllowed = YES;
            
            break;
        }
        case Test_Fonts:
        {
            
            NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:
                                @"[{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 64]}, \"properties\": {\"id\": \"1\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 63]}, \"properties\": {\"id\": \"2\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 62]}, \"properties\": {\"id\": \"3\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 61]}, \"properties\": {\"id\": \"4\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 60]}, \"properties\": {\"id\": \"5\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-25, 58]}, \"properties\": {\"id\": \"6\"}},"
                                "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [-20, 55]}, \"properties\": {\"id\": \"7\"}},"
                                "{\"type\":\"Polygon\",\"coordinates\":[[ [-30, 50], [-30, 80], [-10, 80], [-10, 50] ]]}]"];
            
            GLMapVectorStyle *style = [GLMapVectorStyle createCascadeStyle:
                                       @"node[id=1]{text:'Test12';text-color:black;font-size:5;text-priority:100;}"
                                       @"node[id=2]{text:'Test12';text-color:black;font-size:10;text-priority:100;}"
                                       @"node[id=3]{text:'Test12';text-color:black;font-size:15;text-priority:100;}"
                                       @"node[id=4]{text:'Test12';text-color:black;font-size:20;text-priority:100;}"
                                       @"node[id=5]{text:'Test12';text-color:black;font-size:25;text-priority:100;}"
                                       @"node[id=6]{text:'Test12';text-color:black;font-size:30;text-priority:100;}"
                                       @"node[id=6]{text:'Test12';text-color:black;font-size:60;text-priority:100;}"
                                       @"area{fill-color:white; layer:100;}"
                                       ];
            
            [_mapView addVectorObjects:objects withStyle:style];
            
            UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(350, 200, 150, 200)];
            UIView *testView2 = [[UIView alloc] initWithFrame:CGRectMake(200, 200, 150, 200)];
            testView.backgroundColor = [UIColor blackColor];
            testView2.backgroundColor = [UIColor whiteColor];
            float y = 0;
            
            for(int i=0;i<7;++i)
            {
                UIFont *font = [UIFont fontWithName:@"NotoSans" size:5+5*i];
                
                UILabel *lbl = [[UILabel alloc] init];
                lbl.text = @"Test12";
                lbl.font = font;
                lbl.textColor = [UIColor whiteColor];
                [lbl sizeToFit];
                lbl.frame = CGRectMake(0, y, lbl.frame.size.width, lbl.frame.size.height);
                [testView addSubview:lbl];
                
                UILabel *lbl2 = [[UILabel alloc] init];
                lbl2.text = @"Test12";
                lbl2.font = font;
                lbl2.textColor = [UIColor blackColor];
                [lbl2 sizeToFit];
                lbl2.frame = CGRectMake(0, y, lbl2.frame.size.width, lbl2.frame.size.height);
                [testView2 addSubview:lbl2];
                
                y += lbl.frame.size.height;
            }
            [_mapView addSubview:testView];
            [_mapView addSubview:testView2];
            
            break;
        }
        default:
            break;
    }
}

// Stop rendering when map is hidden to save resources on CADisplayLink calls
-(void)viewDidDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; //Remove link to self from flashObject:
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Example how to add map from resources.
- (void) loadEmbedMap {
    [[GLMapManager sharedManager] addMapWithPath:[[NSBundle mainBundle] pathForResource:@"Montenegro" ofType:@"vm"]];
    //[[GLMapManager manager] addMapWithPath:[[NSBundle mainBundle] pathForResource:@"Belarus" ofType:@"vm"]];
    
    // Move map to the Montenegro capital
    [_mapView moveTo:GLMapGeoPointMake(42.4341, 19.26) zoomLevel:14];
}

// Example how to calcludate zoom level for some bbox
- (void) zoomToBBox {
    // Berlin
    GLMapGeoPoint geoPt1 = GLMapGeoPointMake(52.5037, 13.4102);
    // Minsk
    GLMapGeoPoint geoPt2 = GLMapGeoPointMake(53.9024, 27.5618);
    
    // get internal coordinates of geo points
    GLMapPoint internalPt1 = [GLMapView makeMapPointFromGeoPoint:geoPt1];
    GLMapPoint internalPt2 = [GLMapView makeMapPointFromGeoPoint:geoPt2];
    
    // get pixel positions of geo points
    CGPoint screenPt1 = [_mapView makeDisplayPointFromMapPoint:internalPt1];
    CGPoint screenPt2 = [_mapView makeDisplayPointFromMapPoint:internalPt2];
    
    // get distance in pixels in current zoom level
    CGPoint screenDistance = CGPointMake(fabs(screenPt1.x - screenPt2.x), fabs(screenPt1.y - screenPt2.y));
    
    // get scale beteen current screen size and desired screen size to fit points
    double wscale = screenDistance.x / _mapView.bounds.size.width;
    double hscale = screenDistance.y / _mapView.bounds.size.height;
    double zoomChange = fmax(wscale, hscale);
    
    // set center point and change zoom to make screenDistance less or equal mapView.bounds
    [_mapView setMapCenter:GLMapPointMake((internalPt1.x + internalPt2.x)/2, (internalPt1.y + internalPt2.y)/2)
                      zoom:[_mapView mapZoom]/zoomChange];
}

#pragma mark Download button
-(void) mapDownloaded:(NSNotification *)aNotify
{
    [_mapView reloadTiles];
    [self updateDownloadButton];
}

-(void) updateDownloadButtonText:(NSNotification *)aNotify
{
    if(_mapView.centerTileState == GLMapTileState_NoData)
    {
        GLMapPoint center = [_mapView mapCenter];
        
        _mapToDownload = [[GLMapManager sharedManager] mapAtPoint:center];
        
        if (_mapToDownload && ([_mapToDownload state] == GLMapInfoState_Downloaded || [_mapToDownload distanceFromBorder:center] > 0))
        {
            _mapToDownload = nil;
        }
        
        if(_mapToDownload)
        {
            GLMapDownloadTask *task = [[GLMapManager sharedManager] downloadTaskForMap:_mapToDownload];
            NSString *title;
            if(task && _mapToDownload.state == GLMapInfoState_InProgress)
            {
                title = [NSString stringWithFormat:@"Downloading %@ \u202A%d%%\u202C", [_mapToDownload name] , (int)(_mapToDownload.downloadProgress*100)];
            }else
            {
                title = [NSString stringWithFormat:@"Download %@", [_mapToDownload name]];
            }
            [_downloadButton setTitle:title forState:UIControlStateNormal];
        } else
        {
            [_downloadButton setTitle:@"Download Maps" forState:UIControlStateNormal];
        }
    }
}

-(void) updateDownloadButton
{
    switch (_mapView.centerTileState)
    {
        case GLMapTileState_HasData:
            if(!_downloadButton.hidden)
            {
                _downloadButton.hidden = YES;
            }
            break;
        case GLMapTileState_NoData:
            if(_downloadButton.hidden)
            {
                [self updateDownloadButtonText:nil];
                _downloadButton.hidden = NO;
            }
            break;
        case GLMapTileState_Updating:
            break;
    }
}

- (void)downloadButtonTouchUp:(UIButton *)sender
{
    if(_mapToDownload)
    {
        GLMapDownloadTask *task = [[GLMapManager sharedManager] downloadTaskForMap:_mapToDownload];
        if(task)
        {
            [task cancel];
        }else
        {
            [[GLMapManager sharedManager] downloadMap:_mapToDownload withCompletionBlock:nil];
        }
    } else
    {
        [self performSegueWithIdentifier:@"DownloadMaps" sender:self];
    }
}


#pragma mark Add/move/remove image

-(void) addImage:(id)sender
{
    UIBarButtonItem *button = sender;
    button.title = @"Move image";
    button.action = @selector(moveImage:);
    
    UIImage *img = [UIImage imageNamed:@"pin1.png"];
    
    _mapImage = [_mapView displayImage:img];
    if (_mapImage) {
        _mapImage.position = _mapView.mapCenter;
        _mapImage.offset = CGPointMake(img.size.width/2, 0);
        _mapImage.angle = arc4random_uniform(360);
        _mapImage.rotatesWithMap = YES;
    }
}

-(void) moveImage:(id)sender
{
    UIBarButtonItem *button = sender;
    button.title = @"Remove image";
    button.action = @selector(delImage:);
    
    if(_mapImage)
    {
        _mapImage.position = _mapView.mapCenter;
    }
}

-(void) delImage:(id)sender
{
    UIBarButtonItem *button = sender;
    button.title = @"Add image";
    button.action = @selector(addImage:);
    
    if(_mapImage)
    {
        [_mapView removeImage:_mapImage];
        _mapImage = nil;
    }
}

#pragma mark Test pin
-(BOOL) canBecomeFirstResponder
{
    return YES;
}

-(void) addPin:(id)sender
{
    if(!_mapImageGroup)
    {
        _mapImageGroup = [_mapView createImageGroup];
        
        NSArray *images = @[[UIImage imageNamed:@"pin1.png"],
                            [UIImage imageNamed:@"pin2.png"],
                            [UIImage imageNamed:@"pin3.png"]];
        
        __weak MapViewController *wself = self;
        _imageIDs = [_mapImageGroup setImages:images completion:^{
            for(NSUInteger i=0; i<images.count; i++)
            {
                UIImage *img = images[i];
                [wself.mapImageGroup setImageOffset:CGPointMake(img.size.width/2, 0) forImageWithID:[wself.imageIDs[i] intValue]];
            }
        }];
        
        [_mapImageGroup setObjectFillBlock:^GLMapImageGroupImageInfo(size_t index)
         {
             GLMapImageGroupImageInfo imageInfo;
             
             // Make sure you have pins added and initialized at this point
             Pin *pin = (wself.pins)[index];
             imageInfo.pos = pin.pos;
             imageInfo.imageID = pin.imageID;
             
             return imageInfo;
         }];
        
        _pins = [[NSMutableArray alloc] initWithCapacity:1];
    }
    
    Pin *pin = [[Pin alloc] init];
    pin.pos = [_mapView makeMapPointFromDisplayPoint:_menuPos];
    
    // to iterate over images pin1, pin2, pin3, pin1, pin2, pin3
    NSUInteger imageIDindex = _pins.count % _imageIDs.count;
    pin.imageID = [_imageIDs[imageIDindex] intValue];
    [_pins addObject:pin];
    
    [_mapImageGroup setObjectCount:_pins.count];
    [_mapImageGroup setNeedsUpdate];
}

-(void) deletePin:(id)sender
{
    [_pins removeObject:_pinToDelete];
    [_mapImageGroup setObjectCount:_pins.count];
    [_mapImageGroup setNeedsUpdate];
    _pinToDelete = nil;
    
    if (!_pins.count) {
        [_mapView removeImageGroup:_mapImageGroup];
        _mapImageGroup = nil;
    }
}

// Example how to interact with user
- (void) setupPinGestures {
    __weak GLMapView *weakmap = _mapView;
    __weak MapViewController *wself = self;
    _mapView.longPressGestureBlock = ^(CGPoint pt)
    {
        UIMenuController *menu = [UIMenuController sharedMenuController];
        if (!menu.menuVisible)
        {
            wself.menuPos = pt;
            [wself becomeFirstResponder];
            [menu setTargetRect:CGRectMake(wself.menuPos.x, wself.menuPos.y, 1, 1) inView:weakmap];
            menu.menuItems = @[ [[UIMenuItem alloc] initWithTitle:@"Add pin" action:@selector(addPin:)]];
            [menu setMenuVisible:YES animated:YES];
        }
    };
    
    _mapView.tapGestureBlock = ^(CGPoint pt) {
        CGRect tapRect = CGRectOffset(CGRectMake(-20, -20, 40, 40), pt.x, pt.y);
        
        for (Pin *pin in wself.pins) {
            CGPoint pinPos = [weakmap makeDisplayPointFromMapPoint:pin.pos];
            if( CGRectContainsPoint(tapRect, pinPos) )
            {
                UIMenuController *menu = [UIMenuController sharedMenuController];
                if (!menu.menuVisible)
                {
                    wself.pinToDelete = pin;
                    [wself becomeFirstResponder];
                    [menu setTargetRect:CGRectMake(pinPos.x, pinPos.y-20, 1, 1) inView:weakmap];
                    menu.menuItems = @[ [[UIMenuItem alloc] initWithTitle:@"Delete pin" action:@selector(deletePin:)] ];
                    [menu setMenuVisible:YES animated:YES];
                }
            }
        }
    };
}

// Minimal usage example of marker layer
- (void)addMarkers {
    // Move map to the UK
    [_mapView moveTo:GLMapGeoPointMake(53.46, -2) zoomLevel:6];
    
    // Create marker image
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"cluster" ofType:@"svgpb"];
    UIImage *img = [[GLMapVectorImageFactory sharedFactory] imageFromSvgpb:imagePath withScale:0.2];
    
    // Create style collection - it's storage for all images possible to use for markers
    GLMapMarkerStyleCollection *style = [[GLMapMarkerStyleCollection alloc] init];
    [style addMarkerImage:img];
    
    // Data fill block used to set location for marker and it's style
    // It could work with any user defined object type. GLMapVectorObject in our case.
    [style setMarkerDataFillBlock:^(NSObject *marker, GLMapMarkerData data) {
        // marker - is an object from markers array.
        if ([marker isKindOfClass:[GLMapVectorObject class]]) {
            GLMapVectorObject *obj = (GLMapVectorObject *)marker;
            GLMapMarkerSetLocation(data, obj.point);
            GLMapMarkerSetStyle(data, 0);
        }
    }];
    
    // Load UK postal codes from GeoJSON
    NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"cluster_data" ofType:@"json"];
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromFile:dataPath];
    
    // Put our array of objects into marker layer. It could be any custom array of objects.
    GLMapMarkerLayer *layer = [[GLMapMarkerLayer alloc] initWithMarkers:objects andStyles:style];
    // Disable clustering in this demo
    layer.clusteringEnabled = NO;
    
    // Add marker layer on map
    [_mapView displayMarkerLayer:layer completion:nil];
}

- (void)addMarkersWithClustering {
    // Move map to the UK
    [_mapView moveTo:GLMapGeoPointMake(53.46, -2) zoomLevel:6];
    
    // We use different colours for our clusters
    const int unionCount = 8;
    GLMapColor unionColours[unionCount] = {
        GLMapColorMake(33, 0, 255, 255),
        GLMapColorMake(68, 195, 255, 255),
        GLMapColorMake(63, 237, 198, 255),
        GLMapColorMake(15, 228, 36, 255),
        GLMapColorMake(168, 238, 25, 255),
        GLMapColorMake(214, 234, 25, 255),
        GLMapColorMake(223, 180, 19, 255),
        GLMapColorMake(255, 0, 0, 255)
    };
    
    // Create style collection - it's storage for all images possible to use for markers and clusters
    GLMapMarkerStyleCollection *style = [[GLMapMarkerStyleCollection alloc] init];
    
    // Render possible images from svgpb
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"cluster" ofType:@"svgpb"];
    for (int i=0; i<unionCount; i++) {
        float scale = 0.2 + 0.1 * i;
        UIImage *img = [[GLMapVectorImageFactory sharedFactory] imageFromSvgpb:imagePath withScale:scale andTintColor:unionColours[i]];
        
        [style addMarkerImage:img];
    }
    
    // Create style for text
    GLMapVectorStyle *textStyle = [GLMapVectorStyle createStyle:@"{text-color:black;font-size:12;font-stroke-width:1pt;font-stroke-color:#FFFFFFEE;}"];
    
    // Data fill block used to set location for marker and it's style
    // It could work with any user defined object type. GLMapVectorObject in our case.
    [style setMarkerDataFillBlock:^(NSObject *marker, GLMapMarkerData data) {
        // marker - is an object from markers array.
        if ([marker isKindOfClass:[GLMapVectorObject class]]) {
            GLMapVectorObject *obj = (GLMapVectorObject *)marker;
            GLMapMarkerSetLocation(data, obj.point);
            GLMapMarkerSetStyle(data, 0);
            
            NSString *name = [obj valueForKey:@"name"];
            if (name) {
                GLMapMarkerSetText(data, name, CGPointMake(0, 7), textStyle);
            }
        }
    }];
    
    // Union fill block used to set style for cluster object. First param is number objects inside the cluster and second is marker object.
    [style setMarkerUnionFillBlock:^(uint32_t markerCount, GLMapMarkerData data) {
        // we have 8 marker styles for 1, 2, 4, 8, 16, 32, 64, 128+ markers inside
        int markerStyle = log2(markerCount);
        if (markerStyle >= unionCount) {
            markerStyle = unionCount-1;
        }
        
        GLMapMarkerSetStyle(data, markerStyle);
    }];
    
    // When we have big dataset to load. We could load it in background thread. And create marker layer on main thread only when data is loaded.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"cluster_data" ofType:@"json"];
        NSArray *objects = [GLMapVectorObject createVectorObjectsFromFile:dataPath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            GLMapMarkerLayer *layer = [[GLMapMarkerLayer alloc] initWithMarkers:objects andStyles:style];
            
            // Clustering is enabled by default
            //layer.clusteringEnabled = NO;
    
            [_mapView displayMarkerLayer:layer completion:nil];
        });
    });
}

/* Example how to add multiline objects
 It includes 3 steps
 1. Allocate memory for points and fill points
 2. Setup style objects
 3. Add points to GLMapVectorObject
 4. Add GLMapVector object into the map
 */

- (void) addMultiline {
    // prepare object data
    NSMutableArray *multilineData = [[NSMutableArray alloc] init];
    
    int pointCount = 5;
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(GLMapGeoPoint)*pointCount];
    GLMapGeoPoint *pts= (GLMapGeoPoint *)data.mutableBytes;
    
    pts[0] = GLMapGeoPointMake(53.8869, 27.7151); // Minsk
    pts[1] = GLMapGeoPointMake(50.4339, 30.5186); // Kiev
    pts[2] = GLMapGeoPointMake(52.2251, 21.0103); // Warsaw
    pts[3] = GLMapGeoPointMake(52.5037, 13.4102); // Berlin
    pts[4] = GLMapGeoPointMake(48.8505, 2.3343);  // Paris
    [multilineData addObject:data];
    
    pointCount = 3;
    data = [NSMutableData dataWithLength:sizeof(GLMapPoint)*pointCount];
    pts= (GLMapGeoPoint *)data.mutableBytes;
    
    pts[0] = GLMapGeoPointMake(52.3690, 4.9021); // Amsterdam
    pts[1] = GLMapGeoPointMake(50.8263, 4.3458); // Brussel
    pts[2] = GLMapGeoPointMake(49.6072, 6.1296); // Luxembourg
    [multilineData addObject:data];
    
    // style applied to all lines added. Style is string with mapcss rules. Read more in manual.
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{galileo-fast-draw:true;width: 2pt;color:green;}"];
    
    // All user geometry objects should be drawn trough GLMapVectorObject
    // To load data faster we use NSArray of NSData. Each NSData contains GLMapPoints of one line. Allocate buffers first, then load it using appropriate function.
    GLMapVectorObject *vectorObject = [[GLMapVectorObject alloc] init];
    [vectorObject loadGeoMultiLine:multilineData];
    
    [_mapView addVectorObject:vectorObject withStyle:style onReadyToDraw:nil];
}

-(void) addPolygon
{
    NSMutableArray *outerRings = [[NSMutableArray alloc] init];
    NSMutableArray *innerRings = [[NSMutableArray alloc] init];
    
    int pointCount = 25;
    float radius = 10;
    GLMapGeoPoint centerPoint = GLMapGeoPointMake(53, 27);
    
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(GLMapPoint)*pointCount];
    GLMapGeoPoint *pts = (GLMapGeoPoint *)data.mutableBytes;
    
    // let's display circle
    for (int i=0; i<pointCount; i++) {
        pts[i] = GLMapGeoPointMake(centerPoint.lat + sin(2*M_PI / pointCount * i) * radius,
                                   centerPoint.lon + cos(2*M_PI / pointCount * i) * radius);
    }
    
    [outerRings addObject:data];
    
    // now add hole
    radius = 5;
    data = [NSMutableData dataWithLength:sizeof(GLMapPoint)*pointCount];
    pts = (GLMapGeoPoint *)data.mutableBytes;
    // let's display polygon with random points
    for (int i=0; i<pointCount; i++) {
        pts[i] = GLMapGeoPointMake(centerPoint.lat + sin(2*M_PI / pointCount * i) * radius,
                                   centerPoint.lon + cos(2*M_PI / pointCount * i) * radius);
    }
    [innerRings addObject:data];
    
    GLMapVectorObject *vectorObject = [[GLMapVectorObject alloc] init];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{fill-color:#10106050;}"]; // #RRGGBBAA format
    [vectorObject loadGeoPolygon:@[outerRings, innerRings]];
    
    [_mapView addVectorObject:vectorObject withStyle:style onReadyToDraw:nil];
    
    [_mapView moveTo:centerPoint];
}

// Example how to calcludate zoom level for some bbox
- (void) changeBBox {
    // Minsk
    GLMapGeoPoint geoPt1 = GLMapGeoPointMake(52.5037, 13.4102);
    // Paris
    GLMapGeoPoint geoPt2 = GLMapGeoPointMake(48.8505, 2.3343);
    
    // get internal coordinates of geo points
    GLMapPoint internalPt1 = [GLMapView makeMapPointFromGeoPoint:geoPt1];
    GLMapPoint internalPt2 = [GLMapView makeMapPointFromGeoPoint:geoPt2];
    
    // get pixel positions of geo points
    CGPoint screenPt1 = [_mapView makeDisplayPointFromMapPoint:internalPt1];
    CGPoint screenPt2 = [_mapView makeDisplayPointFromMapPoint:internalPt2];
    
    // get distance in pixels in current zoom level
    CGPoint screenDistance = CGPointMake(fabs(screenPt1.x - screenPt2.x), fabs(screenPt1.y - screenPt2.y));
    
    // get scale beteen current screen size and desired screen size to fit points
    double wscale = screenDistance.x / _mapView.bounds.size.width;
    double hscale = screenDistance.y / _mapView.bounds.size.height;
    double zoomChange = fmax(wscale, hscale);
    
    // set center point and change zoom to make screenDistance less or equal mapView.bounds
    [_mapView setMapCenter:GLMapPointMake((internalPt1.x + internalPt2.x)/2, (internalPt1.y + internalPt2.y)/2)
                      zoom:[_mapView mapZoom]/zoomChange];
}

- (void) testNotifications {
    _mapView.bboxChangedBlock = ^(GLMapBBox bbox) {
        NSLog(@"bboxChangedBlock\torigin:%f %f, size: %f %f", bbox.origin.x, bbox.origin.y, bbox.size.x, bbox.size.y);
    };
    _mapView.mapDidMoveBlock = ^(GLMapBBox bbox) {
        NSLog(@"mapDidMoveBlock\torigin:%f %f, size: %f %f", bbox.origin.x, bbox.origin.y, bbox.size.x, bbox.size.y);
    };
}

#pragma mark GeoJSON

-(void) flashObject:(GLMapVectorObject *)object
{
    if (_flashAdd)
    {
        [_mapView addVectorObject:object withStyle:nil onReadyToDraw:nil];//Will use previous style
    }else
    {
        [_mapView removeVectorObject:object];
    }
    _flashAdd = !_flashAdd;
    [_mapView setNeedsDisplay];
    [self performSelector:@selector(flashObject:) withObject:object afterDelay:1.0];
}

-(void) loadGeoJSONWithCSSStyle
{
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:
                        @"[{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [30.5186, 50.4339]}, \"properties\": {\"id\": \"1\", \"text\": \"test1\"}},"
                        "{\"type\": \"Feature\", \"geometry\": {\"type\": \"Point\", \"coordinates\": [27.7151, 53.8869]}, \"properties\": {\"id\": \"2\", \"text\": \"test2\"}},"
                        "{\"type\":\"LineString\",\"coordinates\": [ [27.7151, 53.8869], [30.5186, 50.4339], [21.0103, 52.2251], [13.4102, 52.5037], [2.3343, 48.8505]]},"
                        "{\"type\":\"Polygon\",\"coordinates\":[[ [0.0, 10.0], [10.0, 10.0], [10.0, 20.0], [0.0, 20.0] ],[ [2.0, 12.0], [ 8.0, 12.0], [ 8.0, 18.0], [2.0, 18.0] ]]}]"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createCascadeStyle:
                               @"node[id=1]{icon-image:\"bus.svgpb\";icon-scale:0.5;icon-tint:green;text:eval(tag('text'));text-color:red;font-size:12;text-priority:100;}"
                               "node|z-9[id=2]{icon-image:\"bus.svgpb\";icon-scale:0.7;icon-tint:blue;;text:eval(tag('text'));text-color:red;font-size:12;text-priority:100;}"
                               "line{linecap: round; width: 5pt; color:blue; layer:100;}"
                               "area{fill-color:green; width:1pt; color:red; layer:100;}"];
    
    [_mapView addVectorObjects:objects withStyle:style];
    
    [self flashObject: objects[0]];
}

- (void) loadPointGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"Point\",\"coordinates\": [30.5186, 50.4339]}"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{icon-image:\"bus.svgpb\";icon-scale:0.5;icon-tint:green;}"];
    [_mapView addVectorObjects:objects withStyle:style];
}

- (void) loadMultiPointGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"MultiPoint\",\"coordinates\": [ [27.7151, 53.8869], [33.5186, 55.4339], [21.0103, 52.2251], [13.4102, 52.5037], [2.3343, 48.8505]]}"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{icon-image:\"bus.svgpb\";icon-scale:0.7;icon-tint:blue;}"];
    [_mapView addVectorObjects:objects withStyle:style];
}

- (void) loadLineStringGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"LineString\",\"coordinates\": [ [27.7151, 53.8869], [30.5186, 50.4339], [21.0103, 52.2251], [13.4102, 52.5037], [2.3343, 48.8505]]}"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{galileo-fast-draw:true; width: 4pt; color:green;}"];
    [_mapView addVectorObjects:objects withStyle:style];
}

- (void) loadMultiLineStringGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"MultiLineString\",\"coordinates\":"
                        "[[[27.7151, 53.8869], [30.5186, 50.4339], [21.0103, 52.2251], [13.4102, 52.5037], [2.3343, 48.8505]],"
                        " [[26.7151, 52.8869], [29.5186, 49.4339], [20.0103, 51.2251], [12.4102, 51.5037], [1.3343, 47.8505]]]}"];
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{galileo-fast-draw:false; linecap: round; width: 5pt; color:blue;}"];
    [_mapView addVectorObjects:objects withStyle:style];
}


- (void) loadPolygonGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"Polygon\",\"coordinates\":"
                        "[[ [0.0, 10.0], [10.0, 10.0], [10.0, 20.0], [0.0, 20.0] ],"
                        " [ [2.0, 12.0], [ 8.0, 12.0], [ 8.0, 18.0], [2.0, 18.0] ]]}"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{fill-color:green}"];
    [_mapView addVectorObjects:objects withStyle:style];
}

- (void) loadMultiPolygonGeoJSON {
    NSArray *objects = [GLMapVectorObject createVectorObjectsFromGeoJSON:@"{\"type\":\"MultiPolygon\",\"coordinates\":"
                        "[[[ [0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0] ],"
                        "  [ [2.0, 2.0], [ 8.0, 2.0], [ 8.0,  8.0], [2.0,  8.0] ]],"
                        " [[ [30.0,0.0], [40.0, 0.0], [40.0, 10.0], [30.0,10.0] ],"
                        "  [ [32.0,2.0], [38.0, 2.0], [38.0,  8.0], [32.0, 8.0] ]]]}"];
    
    GLMapVectorStyle *style = [GLMapVectorStyle createStyle:@"{fill-color:blue; width:1pt; color:red;}"];
    [_mapView addVectorObjects:objects withStyle:style];
}


- (void) loadGeoJSON
{
    [self loadGeoJSONWithCSSStyle];
    
    /*[self loadPointGeoJSON];
     [self loadMultiPointGeoJSON];
     
     [self loadLineStringGeoJSON];
     [self loadMultiLineStringGeoJSON];
     
     [self loadPolygonGeoJSON];
     [self loadMultiPolygonGeoJSON];*/
}

- (void) flyTo:(id)sender {
    GLMapGeoPoint minPt = GLMapGeoPointMake(33, -118), maxPt = GLMapGeoPointMake(48, -85);
    [_mapView flyTo:GLMapGeoPointMake(minPt.lat + (maxPt.lat - minPt.lat)*drand48(), minPt.lon + (maxPt.lon - minPt.lon)*drand48()) zoomLevel:14];
}

@end