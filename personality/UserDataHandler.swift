//
//  UserDataHandler.swift
//  personality
//
//  Created by Martin Conklin on 2016-08-05.
//  Copyright © 2016 Martin Conklin. All rights reserved.
//

import Foundation
import CoreData
import AWSDynamoDB
import AWSCognito
import FBSDKLoginKit



class UserDataHandler: NSObject {
    var managedObjectContext: NSManagedObjectContext?
    var credentialsProvider: AWSCognitoCredentialsProvider?
    var defaults = NSUserDefaults.standardUserDefaults()
    
    func saveUserData(userData: AnyObject) {
        let id = userData.valueForKey("id")
        let fetchRequest = NSFetchRequest(entityName: "User")
        let userPredicate = NSPredicate(format: "id == %@", argumentArray: [id!])
        fetchRequest.predicate = userPredicate
        
        var userArray: [User]?
        
        do {
            userArray = try managedObjectContext!.executeFetchRequest(fetchRequest) as? [User]
        } catch let getUserError as NSError {
            print("Error fetching User: \(getUserError)")
        }
        var user: AnyObject?
        
        if userArray?.count > 0 {
            user = userArray![0]
            print("User Array")
        } else {
            let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: managedObjectContext!)
            user = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext!)
            
        }
        
        user?.setValue(userData.valueForKey("id"), forKey: "id")
        user?.setValue(userData.valueForKey("email"), forKey: "email")
        user?.setValue(userData.valueForKey("last_name"), forKey: "lastname")
        user?.setValue(userData.valueForKey("first_name"), forKey: "firstname")
        user?.setValue(userData.valueForKey("gender"), forKey: "gender")
        user?.setValue(userData.valueForKey("political"), forKey: "political")
        user?.setValue(userData.valueForKey("religion"), forKey: "religion")
        user?.setValue(userData.valueForKey("hometown")?.valueForKey("name"), forKey: "hometown")
        user?.setValue(userData.valueForKey("location")?.valueForKey("name"), forKey: "location")
        
        let posts = userData.valueForKey("feed")?.valueForKey("data") as!
            [AnyObject]
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        
        for item in posts {
            if let message = item.valueForKey("message") {
                let date = item.valueForKey("created_time") as! String
                let dateValue = dateFormatter.dateFromString(date)
                let epoch = dateValue?.timeIntervalSince1970
                let entity = NSEntityDescription.entityForName("Post", inManagedObjectContext: managedObjectContext!)
                let post = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext!)
                post.setValue(message, forKey: "message")
                post.setValue(epoch!, forKey: "dateCreated")
                post.setValue(user, forKey: "user")
            }
        }
        saveUserToDynamoDB(id!)
        savePostToDynamoDB(id!)
    }
    
    
    private func saveUserToDynamoDB(id: AnyObject) {
        let fetchRequest = NSFetchRequest(entityName: "User")
        let userPredicate = NSPredicate(format: "id == %@", argumentArray: [id])
        fetchRequest.predicate = userPredicate
        
        var userArray: [User]?
        
        do {
            userArray = try managedObjectContext!.executeFetchRequest(fetchRequest) as? [User]
        } catch let getUserError as NSError {
            print("Error fetching User: \(getUserError)")
        }
        
        let user = userArray![0]
    
        let userMapper = UserMapper()
        
        userMapper.firstname = user.firstname!
        userMapper.lastname = user.lastname!
        userMapper.gender = user.gender!
        userMapper.hometown = user.hometown!
        userMapper.email = user.email!
        userMapper.UserID = (defaults.valueForKey("AWSUserID") as! String)
        userMapper.location = user.location!
        userMapper.political = user.political!
        userMapper.religion = user.religion!
        
        if(credentialsProvider == nil){
            credentialsProvider = AWSCognitoCredentialsProvider.init(regionType: Constants.regionType, identityId: nil, accountId: nil, identityPoolId: Constants.idPool, unauthRoleArn: nil, authRoleArn: nil, logins: nil)
            print("***Credentials was nil***")
        }
        let idToken = FBSDKAccessToken.currentAccessToken().tokenString
        credentialsProvider!.logins = [AWSCognitoLoginProviderKey.Facebook.rawValue : idToken]

        let configuration = AWSServiceConfiguration(region: Constants.regionType, credentialsProvider: credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration

        
        let mapper = AWSDynamoDBObjectMapper.defaultDynamoDBObjectMapper()
        mapper.save(userMapper).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if(task.error != nil) {
                print("Dynamo Error: \(task.error)")
                return nil
            }
            return nil
        }

    }
    
    private func savePostToDynamoDB(id: AnyObject) {
        let fetchRequest = NSFetchRequest(entityName: "User")
        let userPredicate = NSPredicate(format: "id == %@", argumentArray: [id])
        fetchRequest.predicate = userPredicate
        
        var userArray: [User]?
        
        do {
            userArray = try managedObjectContext!.executeFetchRequest(fetchRequest) as? [User]
        } catch let getUserError as NSError {
            print("Error fetching User: \(getUserError)")
        }
        
        let user = userArray![0]
        let facebookPost = PostMapper()
        
        
        for item in user.posts! {
            let post = item as! Post
            facebookPost.UserID = (defaults.valueForKey("AWSUserID") as! String)
            facebookPost.message = post.message
            facebookPost.DateCreated = post.dateCreated
            
            let idToken = FBSDKAccessToken.currentAccessToken().tokenString
            credentialsProvider!.logins = [AWSCognitoLoginProviderKey.Facebook.rawValue : idToken]
            
            let configuration = AWSServiceConfiguration(region: Constants.regionType, credentialsProvider: credentialsProvider)
            
            AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
            
            
            let mapper = AWSDynamoDBObjectMapper.defaultDynamoDBObjectMapper()
            mapper.save(facebookPost).continueWithBlock { (task: AWSTask!) -> AnyObject! in
                if(task.error != nil) {
                    print("Dynamo Error: \(task.error)")
                    return nil
                }
                return nil
            }
            let toneAnalyzer = WatsonToneAnalyzer()
            toneAnalyzer.analyzeTone(post.message!)


            
        }

    }
    
}
