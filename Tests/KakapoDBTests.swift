//
//  KakapoDBTests.swift
//  Kakapo
//
//  Created by Joan Romano on 31/03/16.
//  Copyright © 2016 devlucky. All rights reserved.
//

import Quick
import Nimble
@testable import Kakapo

struct UserFactory: Storable, Serializable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let age: Int
    
    init(id: String, db: KakapoDB) {
        self.init(firstName: "tmp", lastName: "tmp", age: random(), id: id)
    }
    
    init(firstName: String, lastName: String, age: Int, id: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.id = id
    }
}

func ==(lhs: UserFactory, rhs: UserFactory) -> Bool {
    return lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName && lhs.age == rhs.age && lhs.id == rhs.id
}

struct CommentFactory: Storable {
    let id: String
    let text: String
    let likes: Int
    
    init(id: String, db: KakapoDB) {
        self.init(text: "tmp", likes: random(), id: id)
    }
    
    init(text: String, likes: Int, id: String) {
        self.text = text
        self.likes = likes % 200
        self.id = id
    }
}

extension CommentFactory: Equatable {}

func ==(lhs: CommentFactory, rhs: CommentFactory) -> Bool {
    return lhs.text == rhs.text && lhs.likes == rhs.likes && lhs.id == rhs.id
}

class KakapoDBTests: QuickSpec {
    
    override func spec() {
        
        var sut = KakapoDB()
        
        beforeEach {
            sut = KakapoDB()
        }
        
        describe("Creation and Insertion") {
            it("should create a large number of elements") {
                let queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT)
                dispatch_apply(1000, queue, { i in
                    sut.create(UserFactory)
                })
                
                dispatch_apply(5000, queue, { i in
                    sut.create(CommentFactory)
                })
                
                let userObjects = sut.findAll(UserFactory)
                let user = sut.find(UserFactory.self, id: "1")
                
                let commentObjects = sut.findAll(CommentFactory)
                let aComment = sut.find(CommentFactory.self, id: "1000")
                let anotherComment = sut.find(CommentFactory.self, id: "1002")
                
                expect(user).toNot(beNil())
                expect(user?.firstName).toNot(beNil())
                expect(user?.id) == "1"
                expect(userObjects.count) == 1000
                
                expect(aComment).toNot(beNil())
                expect(aComment?.text).toNot(beNil())
                expect(aComment?.id) == "1000"
                
                expect(anotherComment).toNot(beNil())
                expect(anotherComment?.text).toNot(beNil())
                expect(anotherComment?.id) == "1002"
                
                expect(commentObjects.count) == 5000
            }
            
            it("should create a large number of elements respecting the previous ones") {
                let queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT)
                dispatch_apply(1000, queue, { i in
                    sut.create(UserFactory)
                })
                
                let createdObjects = sut.create(UserFactory.self, number: 20000)
                let totalObjects = sut.findAll(UserFactory)
                
                expect(createdObjects.count) == 20000
                expect(totalObjects.count) == 21000
            }
            
            it("should insert a large number of elements") {
                dispatch_apply(1000, dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT), { _ in
                    sut.insert{ (id) -> (UserFactory) in
                        return UserFactory(firstName: "Name " + id, lastName: "Last Name " + id, age: 10, id: id)
                    }
                })
                
                let userObjects = sut.findAll(UserFactory)
                let user = sut.find(UserFactory.self, id: "1")
                
                expect(user).toNot(beNil())
                expect(user?.firstName).to(contain("Name 1"))
                expect(user?.lastName).to(contain("Last Name 1"))
                expect(user?.id).to(equal("1"))
                expect(user?.age).to(equal(10))
                expect(userObjects.count) == 1000
            }
        }
        
        describe("Finding and Filtering") {
            it("should return the expected object with a given id after inserting multiple objects") {
                sut.create(UserFactory.self, number: 3)
                let user = sut.find(UserFactory.self, id: "1")
                
                expect(user).toNot(beNil())
                expect(user?.firstName).toNot(beNil())
                expect(user?.id) == "1"
            }
            
            it("should return the expected object with a given id after inserting different object types") {
                sut.create(UserFactory.self, number: 3)
                sut.create(CommentFactory.self, number: 2)
                let user = sut.find(UserFactory.self, id: "1")
                let wrongComment = sut.find(CommentFactory.self, id: "2")
                let comment = sut.find(CommentFactory.self, id: "3")
                
                expect(user).toNot(beNil())
                expect(wrongComment).to(beNil())
                expect(comment).toNot(beNil())
            }
            
            it("shoud return the expected object after inserting it") {
                sut.insert { (id) -> UserFactory in
                    return UserFactory(firstName: "Hector", lastName: "Zarco", age:25, id: id)
                }
                
                let user = sut.find(UserFactory.self, id: "0")
                expect(user?.firstName).to(match("Hector"))
                expect(user?.lastName).to(match("Zarco"))
                expect(user?.id) == "0"
            }
            
            it("should fail a precondition when inserting invalid id") {
                sut.insert { (id) -> UserFactory in
                    return UserFactory(firstName: "Joan", lastName: "Romano", age:25, id: id)
                }

                self.expectPrecondition("Tried to insert an invalid id") {
                    sut.insert { (id) -> UserFactory in
                        return UserFactory(firstName: "Joan", lastName: "Romano", age:25, id: String(Int(id)! - 1))
                    }
                }
            }

            it("should return the expected filtered element with valid id") {
                sut.insert { (id) -> UserFactory in
                    UserFactory(firstName: "Hector", lastName: "Zarco", age:25, id: id)
                }
                
                let userArray = sut.filter(UserFactory.self) { (item) -> Bool in
                    return item.id == "0"
                }
                
                expect(userArray.count) == 1
                expect(userArray.first?.firstName).to(match("Hector"))
                expect(userArray.first?.lastName).to(match("Zarco"))
                expect(userArray.first?.id) == "0"
            }

            it("should return no objects for some inexisting filtering") {
                sut.create(UserFactory.self, number: 2)
                sut.insert { (id) -> UserFactory in
                    return UserFactory(firstName: "Hector", lastName: "Zarco", age:25, id: id)
                }
                
                let userArray = sut.filter(UserFactory.self, includeElement: { (item) -> Bool in
                    return item.lastName == "Manzella"
                })
                
                expect(userArray.count) == 0
            }
        }
        
        describe("Update") {
            it("should update a previously inserted object") {
                sut.create(UserFactory.self, number: 3)
                let elementToUpdate = UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: "2")
                try! sut.update(elementToUpdate)
                let updatedUserInDb = sut.find(UserFactory.self, id: "2")
                
                expect(updatedUserInDb?.firstName).to(equal("Joan"))
                expect(updatedUserInDb?.lastName).to(equal("Romano"))
                expect(updatedUserInDb?.age).to(equal(28))
            }
            
            it("should not update an object that was never inserted") {
                sut.create(UserFactory.self, number: 2)
                let elementToUpdate = UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: "45")
                expect{ try sut.update(elementToUpdate) }.to(throwError(errorType: KakapoDBError.self))
                let updatedUserInDb = sut.find(UserFactory.self, id: "45")
                expect(updatedUserInDb).to(beNil())
            }
            
            it("should not update different kind of objects from different databases with same id") {
                let anotherDB = KakapoDB()
                sut.create(UserFactory.self, number: 2)
                anotherDB.create(CommentFactory.self, number: 2)
                expect{ try sut.update(anotherDB.find(CommentFactory.self, id: "0")!) }.to(throwError(errorType: KakapoDBError.self))
                let updatedCommentInDb = sut.find(CommentFactory.self, id: "0")
                expect(updatedCommentInDb).to(beNil())
            }
            
            it("should update same kind of objects from different databases with same id") {
                let anotherDB = KakapoDB()
                var theId: String!
                let factory = sut.create(CommentFactory).first!
                let likes = factory.likes
                
                anotherDB.insert { (id) -> CommentFactory in
                    theId = id
                    return CommentFactory(text: "a comment", likes: likes + 1, id: id)
                }
                
                try! sut.update(anotherDB.find(CommentFactory.self, id: theId)!)
                let updatedComment = sut.find(CommentFactory.self, id: theId)
                
                expect(updatedComment?.text).to(equal("a comment"))
                expect(updatedComment?.likes).to(equal(likes + 1))
            }
        }
        
        describe("Deletion") {
            it("should delete a previously inserted object") {
                sut.create(UserFactory.self, number: 5)
                let elementToDelete = sut.find(UserFactory.self, id: "2")!
                try! sut.delete(elementToDelete)
                let usersArray = sut.findAll(UserFactory)
                
                expect(usersArray.count).to(equal(4))
            }
            
            it("should delete a previously inserted object with same data representation") {
                var theId: String!
                sut.insert { (id) -> UserFactory in
                    theId = id
                    return UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: id)
                }
                
                let elementToDelete = UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: theId)
                try! sut.delete(elementToDelete)
                let usersArray = sut.findAll(UserFactory)
                
                expect(usersArray.count).to(equal(0))
            }
            
            it("should not delete an object with same id but different type") {
                let userFactory = sut.create(UserFactory).first!
                let elementToDelete = CommentFactory(text: "", likes: 0, id: userFactory.id)
                expect{ try sut.delete(elementToDelete) }.to(throwError(errorType: KakapoDBError.self))
                expect(sut.findAll(UserFactory).count).to(equal(1))
            }
            
            it("should delete an object with same id and same type but different properties") {
                let commentFactory = sut.create(CommentFactory).first!
                let elementToDelete = CommentFactory(text: "", likes: commentFactory.likes + 1, id: commentFactory.id)
                expect(commentFactory).toNot(equal(elementToDelete))
                expect{ try sut.delete(elementToDelete) }.toNot(throwError(errorType: KakapoDBError.self))
                expect(sut.findAll(UserFactory).count).to(equal(0))
            }
            
            it("should not delete a non previously inserted object") {
                sut.create(UserFactory.self)
                let elementToDelete = UserFactory(id: "44", db: sut)
                expect{ try sut.delete(elementToDelete) }.to(throwError(errorType: KakapoDBError.self))
                expect(sut.findAll(UserFactory).count).to(equal(1))
            }
            
            it("should not delete objects from different databases with same id") {
                let anotherDB = KakapoDB()
                sut.create(UserFactory.self, number: 2)
                anotherDB.create(CommentFactory.self, number: 2)
                expect{ try sut.delete(anotherDB.find(CommentFactory.self, id: "1")!) }.to(throwError(errorType: KakapoDBError.self))
                expect(sut.findAll(UserFactory).count).to(equal(2))
            }
            
            it("should delete objects from different databases with same id and data representation") {
                let anotherDB = KakapoDB()
                var theId: String!
                sut.insert { (id) -> UserFactory in
                    theId = id
                    return UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: id)
                }
                
                sut.create(UserFactory.self, number: 44)
                
                anotherDB.insert { (id) -> UserFactory in
                    return UserFactory(firstName: "Joan", lastName: "Romano", age: 28, id: id)
                }
                
                let elementToDelete = anotherDB.find(UserFactory.self, id: theId)!
                try! sut.delete(elementToDelete)
                let usersArray = sut.findAll(UserFactory)
                
                expect(usersArray.count).to(equal(44))
            }
            
            it("should have no items after deleting all") {
                let sut = KakapoDB()
                sut.create(UserFactory.self, number: 2000)
                for entity in sut.findAll(UserFactory) {
                    try! sut.delete(entity)
                }
                
                expect(sut.findAll(UserFactory).count).to(equal(0))
            }
            
            it("should be able to concurrently delete objects") {
                let users = sut.create(UserFactory.self, number: 100)
                
                dispatch_apply(100, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { i in
                    try! sut.delete(users[i])
                }
                
                expect(sut.findAll(UserFactory).count).to(equal(0))
            }
            
            it("should be able to concurrently update and delete objects") {
                let users = sut.create(UserFactory.self, number: 100)
                
                dispatch_apply(100, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { i in
                    try! sut.update(users[i])
                    try! sut.delete(users[i])
                }
                
                expect(sut.findAll(UserFactory).count).to(equal(0))
            }
        }
        
        describe("Database Operations Deadlock 💀💀💀💀💀💀💀💀") {
            let queue = dispatch_queue_create("com.kakapodb.testDeadlock", DISPATCH_QUEUE_SERIAL)
            
            beforeEach {
                sut.insert { id -> UserFactory in
                   return UserFactory(id: id, db: sut)
                }
            }
            
            it("should not deadlock when writing into database during a writing operation") {
                let user = sut.insert { (id) -> UserFactory in
                    sut.insert { (id) -> UserFactory in
                        return UserFactory(id: id, db: sut)
                    }
                    
                    return UserFactory(id: id, db: sut)
                }
                
                expect(user).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously writing from another queue into database during a writing operation") {
                let user = sut.insert { (id) -> UserFactory in
                    dispatch_sync(queue) {
                        sut.insert { (id) -> UserFactory in
                            return UserFactory(id: id, db: sut)
                        }
                    }
                    return UserFactory(id: id, db: sut)
                }
                expect(user).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when writing into database during a reading operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    sut.create(UserFactory)
                    return true
                })
                
                expect(result).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously writing from another queue into database during a reading operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    dispatch_sync(queue) {
                        sut.create(UserFactory)
                    }
                    return true
                })
                
                expect(result).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when reading the database during a read operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    sut.findAll(UserFactory)
                    return true
                })
                
                expect(result).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously reading the database from another queue during a reading operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    dispatch_sync(queue) {
                        sut.findAll(UserFactory)
                    }
                    return true
                })
                
                expect(result).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when reading the database during a write operation") {
                let user = sut.insert { (id) -> UserFactory in
                    sut.findAll(UserFactory)
                    return UserFactory(id: id, db: sut)
                }
                expect(user).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously reading the database from another queue during a write operation") {
                let user = sut.insert { (id) -> UserFactory in
                    dispatch_sync(queue) {
                        sut.findAll(UserFactory)
                    }
                    return UserFactory(id: id, db: sut)
                }
                expect(user).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously updating the database from another queue during a write operation") {
                let user = sut.insert { (id) -> UserFactory in
                    dispatch_sync(queue) {
                        try! sut.update(UserFactory(id: "0", db: sut))
                    }
                    return UserFactory(id: id, db: sut)
                }
                expect(user).toEventuallyNot(beNil())
            }
            
            it("should not deadlock when synchronously deleting the database from another queue during a write operation") {
                let user = sut.insert { (id) -> UserFactory in
                    dispatch_sync(queue) {
                        try! sut.delete(sut.find(UserFactory.self, id: "0")!)
                    }
                    return UserFactory(id: id, db: sut)
                }
                
                let users = sut.findAll(UserFactory)
                
                expect(user).toEventuallyNot(beNil())
                expect(users.count).toEventually(equal(1))
            }
            
            it("should not deadlock when deleting into database during a reading operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    try! sut.delete(sut.find(UserFactory.self, id: "0")!)
                    return true
                })
                
                let users = sut.findAll(UserFactory)
                
                expect(result).toEventuallyNot(beNil())
                expect(users.count).toEventually(equal(0))
            }
            
            it("should not deadlock when updating into database during a reading operation") {
                let result = sut.filter(UserFactory.self, includeElement: { (_) -> Bool in
                    try! sut.update(UserFactory(firstName: "Alex", lastName: "Manzella", age: 30, id: "0"))
                    return true
                })
                
                let user = sut.findAll(UserFactory).first!
                
                expect(result).toEventuallyNot(beNil())
                expect(user.firstName).toEventually(equal("Alex"))
                expect(user.lastName).toEventually(equal("Manzella"))
                expect(user.age).toEventually(equal(30))
            }
        }
    }
}

class KakapoDBPerformaceTests: XCTestCase {
    
    func testMultipleSingleCreationPerformance() {
        let sut = KakapoDB()
        measureBlock {
            dispatch_apply(1000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { _ in
                sut.create(UserFactory)
            }
        }
    }
    
    func testMultpleInsertionsPerformance() {
        let sut = KakapoDB()
        measureBlock {
            dispatch_apply(1000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { _ in
                sut.insert { (id) -> UserFactory in
                    return UserFactory(id: id, db: sut)
                }
            }
        }
    }
    
    func testMultipleDeletionsPerformance() {
        let sut = KakapoDB()
        sut.create(UserFactory.self, number: 2000)
        measureBlock {
            for entity in sut.findAll(UserFactory) {
                try! sut.delete(entity)
            }
        }
    }
}