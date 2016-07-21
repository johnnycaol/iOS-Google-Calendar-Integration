//
//  ViewController.swift
//  QuickstartApp
//
//  Created by Luchao Cao on 2016-07-14.
//  Copyright © 2016 com.example. All rights reserved.
//

import GoogleAPIClient
import GTMOAuth2
import UIKit

class ViewController: UIViewController {
    
    private let kKeychainItemName = "Google Calendar API"
    private let kClientID = "963744635405-v35a7e2f5gdji4jonsqqlp26nng5k4hh.apps.googleusercontent.com"
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    private let scopes = [kGTLAuthScopeCalendarReadonly]
    private let service = GTLServiceCalendar()
    
    let output = UITextView()
    
    // When the view loads, create necessary subviews
    // and initialize the Google Calendar API service
    override func viewDidLoad() {
        super.viewDidLoad()
        
        output.frame = view.bounds
        output.editable = false
        output.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        output.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        
        view.addSubview(output);
        
        if let auth = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychainForName(
            kKeychainItemName,
            clientID: kClientID,
            clientSecret: nil) {
            service.authorizer = auth
        }
        
    }
    
    // When the view appears, ensure that the Google Calendar API service is authorized
    // and perform API calls
    override func viewDidAppear(animated: Bool) {
        if let authorizer = service.authorizer,
            canAuth = authorizer.canAuthorize where canAuth {
            fetchEvents()
        } else {
            presentViewController(
                createAuthController(),
                animated: true,
                completion: nil
            )
        }
    }
    
    // Construct a query and get a list of upcoming events from the user calendar
    func fetchEvents() {
        let query = GTLQueryCalendar.queryForEventsListWithCalendarId("primary")
        query.maxResults = 20
        query.timeMin = GTLDateTime(date: NSDate(), timeZone: NSTimeZone.localTimeZone())
        query.singleEvents = true
        query.q = "1:1 johnny@soapboxhq.com justin@soapboxhq.com"//append the current user's email and the colleague's email
        query.orderBy = kGTLCalendarOrderByStartTime //comment this out as it doesn't work with singleEvents = false
        service.executeQuery(
            query,
            delegate: self,
            didFinishSelector: "displayResultWithTicket:finishedWithObject:error:"
        )
    }
    
    func createEvent() {
        let event = GTLCalendarEvent()
        event.summary = "Amazing event"
        event.start = //TODO: add date here
        let query = GTLQueryCalendar.queryForEventsInsertWithObject(event, calendarId: "primary")
    }
    
    /*
     Event event = new Event()
     .setSummary("Google I/O 2015")
     .setLocation("800 Howard St., San Francisco, CA 94103")
     .setDescription("A chance to hear more about Google's developer products.");
     
     DateTime startDateTime = new DateTime("2015-05-28T09:00:00-07:00");
     EventDateTime start = new EventDateTime()
     .setDateTime(startDateTime)
     .setTimeZone("America/Los_Angeles");
     event.setStart(start);
     
     DateTime endDateTime = new DateTime("2015-05-28T17:00:00-07:00");
     EventDateTime end = new EventDateTime()
     .setDateTime(endDateTime)
     .setTimeZone("America/Los_Angeles");
     event.setEnd(end);
     
     String[] recurrence = new String[] {"RRULE:FREQ=DAILY;COUNT=2"};
     event.setRecurrence(Arrays.asList(recurrence));
     
     EventAttendee[] attendees = new EventAttendee[] {
     new EventAttendee().setEmail("lpage@example.com"),
     new EventAttendee().setEmail("sbrin@example.com"),
     };
     event.setAttendees(Arrays.asList(attendees));
     
     EventReminder[] reminderOverrides = new EventReminder[] {
     new EventReminder().setMethod("email").setMinutes(24 * 60),
     new EventReminder().setMethod("popup").setMinutes(10),
     };
     Event.Reminders reminders = new Event.Reminders()
     .setUseDefault(false)
     .setOverrides(Arrays.asList(reminderOverrides));
     event.setReminders(reminders);
     
     String calendarId = "primary";
     event = service.events().insert(calendarId, event).execute();
     System.out.printf("Event created: %s\n", event.getHtmlLink());
     */
    
    // Display the start dates and event summaries in the UITextView
    func displayResultWithTicket(
        ticket: GTLServiceTicket,
        finishedWithObject response : GTLCalendarEvents,
                           error : NSError?) {
        
        if let error = error {
            showAlert("Error", message: error.localizedDescription)
            return
        }
        
        var eventString = ""
        
        if let events = response.items() where !events.isEmpty {
            for event in events as! [GTLCalendarEvent] {
                
                let start : GTLDateTime! = event.start.dateTime ?? event.start.date
                let startString = NSDateFormatter.localizedStringFromDate(
                    start.date,
                    dateStyle: .ShortStyle,
                    timeStyle: .ShortStyle
                )
                
                let end : GTLDateTime! = event.end.dateTime ?? event.end.date
                let endString = NSDateFormatter.localizedStringFromDate(
                    end.date,
                    dateStyle: .ShortStyle,
                    timeStyle: .ShortStyle
                )
                
                print(event)
                print("ID: " + event.identifier)
                print("Start: " + startString)
                print("End: " + endString)
                if let recurringEventId = event.recurringEventId {
                    print("Recurring Event Id: \(recurringEventId)")//use this id to aggregate events from the same recurring event
                }
                
                if let description = event.summary {
                    print("Description: \(description)")
                }
                
                if let location = event.location {
                    print("Location: \(location)")
                }
                print("\n")
                eventString += "\(startString) - \(event.summary)\n"
            }
        } else {
            eventString = "No upcoming events found."
        }
        
        output.text = eventString
    }
    
    
    // Creates the auth controller for authorizing access to Google Calendar API
    private func createAuthController() -> GTMOAuth2ViewControllerTouch {
        let scopeString = scopes.joinWithSeparator(" ")
        return GTMOAuth2ViewControllerTouch(
            scope: scopeString,
            clientID: kClientID,
            clientSecret: nil,
            keychainItemName: kKeychainItemName,
            delegate: self,
            finishedSelector: "viewController:finishedWithAuth:error:"
        )
    }
    
    // Handle completion of the authorization process, and update the Google Calendar API
    // with the new credentials.
    func viewController(vc : UIViewController,
                        finishedWithAuth authResult : GTMOAuth2Authentication, error : NSError?) {
        
        if let error = error {
            service.authorizer = nil
            showAlert("Authentication Error", message: error.localizedDescription)
            return
        }
        
        service.authorizer = authResult
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Helper for showing an alert
    func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.Default,
            handler: nil
        )
        alert.addAction(ok)
        presentViewController(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

