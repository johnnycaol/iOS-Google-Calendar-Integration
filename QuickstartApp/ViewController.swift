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
    private let scopes = [kGTLAuthScopeCalendar]
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
            //getEvent("nb4e7lbuve74h6m0hhncs52r9s")
            //updateEvent("nb4e7lbuve74h6m0hhncs52r9s", "This event has been updated.")
            createEvent("johnny@soapboxhq.com",
                   participantEmail: "justin@soapboxhq.com",
                   startDate: NSDate(),
                   endDate: NSDate(timeInterval: 60*60*3, sinceDate: NSDate()),
                   summary: "New 1 on 1 for August",
                   recurrenceRule: "RRULE:FREQ=DAILY;COUNT=3"
            )
            //fetchEvents("johnny@soapboxhq.com", participantEmail: "graham@soapboxhq.com")
            //deleteEvent("nb4e7lbuve74h6m0hhncs52r9s")
        } else {
            presentViewController(
                createAuthController(),
                animated: true,
                completion: nil
            )
        }
    }
    
    // Fetch a list of upcoming 1:1 events from the user calendar
    func fetchEvents(userEmail: String, participantEmail: String) {
        let query = GTLQueryCalendar.queryForEventsListWithCalendarId("primary")
        query.maxResults = 20
        query.timeMin = GTLDateTime(date: NSDate(), timeZone: NSTimeZone.localTimeZone())
        query.singleEvents = true
        query.q = "1:1 \(userEmail) \(participantEmail)"//append the current user's email and the colleague's email
        query.orderBy = kGTLCalendarOrderByStartTime //comment this out as it doesn't work with singleEvents = false

        service.executeQuery(
            query,
            delegate: self,
            didFinishSelector: #selector(ViewController.displayResultWithTicket(_:finishedWithObject:error:))
        )
    }
    
    // Get an event by id
    func getEvent(eventId: String) {
        let query = GTLQueryCalendar.queryForEventsGetWithCalendarId("primary", eventId: eventId)
        
        service.executeQuery(
            query,
            delegate: self,
            didFinishSelector: #selector(ViewController.displayResultSingle(_:finishedWithObject:error:))
        )
    }
    
    // Create an event
    // If the user create an event in app, create the event in Google Calendar First, then pull from Google Calendar, and then save to the app
    func createEvent(userEmail: String, participantEmail: String, startDate: NSDate, endDate: NSDate, summary: String, recurrenceRule: String) {
        let event = GTLCalendarEvent()
        
        event.start = GTLCalendarEventDateTime()
        event.start.dateTime = GTLDateTime(date: startDate, timeZone: NSTimeZone.localTimeZone())
        event.start.timeZone = NSTimeZone.localTimeZone().name
        event.end = GTLCalendarEventDateTime()
        event.end.dateTime = GTLDateTime(date: endDate, timeZone: NSTimeZone.localTimeZone())
        event.end.timeZone = NSTimeZone.localTimeZone().name
        event.summary = summary
        event.recurrence = [recurrenceRule]
        
        let attendee1 = GTLCalendarEventAttendee()
        let attendee2 = GTLCalendarEventAttendee()
        attendee1.email = userEmail
        attendee2.email = participantEmail
        event.attendees = [attendee1, attendee2]
        
        let query = GTLQueryCalendar.queryForEventsInsertWithObject(event, calendarId: "primary")
        
        service.executeQuery(
            query,
            delegate: self,
            didFinishSelector: #selector(ViewController.displayResultSingle(_:finishedWithObject:error:))
        )
    }
    
    // Update an event by id
    func updateEvent(eventId: String, summary: String) {
        let query = GTLQueryCalendar.queryForEventsGetWithCalendarId("primary", eventId: eventId)
        service.executeQuery(query, completionHandler: { (ticket, event, error) -> Void in
            if let error = error {
                self.showAlert("Error", message: error.localizedDescription)
            }
            
            let event = event as! GTLCalendarEvent
            event.summary = summary
            
            let query = GTLQueryCalendar.queryForEventsUpdateWithObject(event, calendarId: "primary", eventId: eventId)
            self.service.executeQuery(
                query,
                delegate: self,
                didFinishSelector: #selector(ViewController.displayResultSingle(_:finishedWithObject:error:))
            )
        })
    }
    
    // Delete an event by id
    func deleteEvent(eventId: String) {
        let query = GTLQueryCalendar.queryForEventsDeleteWithCalendarId("primary", eventId: eventId)
        
        service.executeQuery(query, completionHandler: { (ticket, event, error) -> Void in
            if let error = error {
                self.showAlert("Error", message: error.localizedDescription)
            }
        })
    }
    
    func displayResultSingle(
        ticket: GTLServiceTicket,
        finishedWithObject event : GTLCalendarEvent,
                           error : NSError?) {
        
        if let error = error {
            showAlert("Error", message: error.localizedDescription)
            return
        }
        
        var eventString = ""
                
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
        output.text = eventString
    }
    
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
                print(event.recurrence[0])
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
            finishedSelector: #selector(ViewController.viewController(_:finishedWithAuth:error:))
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

