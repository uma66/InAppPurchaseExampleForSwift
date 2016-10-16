//
//  UMLProductPurchaseManager.swift
//
//  Created by uma66 on 2016/09/05.
//  Copyright © 2016年
//

import StoreKit

enum UMLRequestProductResult {
    case Success([SKProduct]?)
    case Failure
    case Error(NSError)
}

enum UMLPurchaseResult {
    case Success
    case Failure
}

typealias PurchaseCompletion = (UMLPurchaseResult) -> Void

class UMLProductPurchaseManager : NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    static let sharedInstance = UMLProductPurchaseHelper()
    private override init() {}
    
    private var productsInfoCompletion: ((UMLRequestProductResult) -> Void?
    private var purchaseCompletion: PurchaseCompletion?
    
    func addTransactionObserver() {
        SKPaymentQueue.defaultQueue().addTransactionObserver(self)
        let transactions = SKPaymentQueue.defaultQueue().transactions
        print("未処理のトランザクション数: \(transactions.count)")
    }
    
    // Getting product info from iTunes Store.
    
    func requestProductInfo(completionHandelr: (UMLRequestProductResult) -> Void) {
        
        if self.canMakePayments() == false {
            completionHandelr(.Failure)
            return
        }
        
        self.productsInfoCompletion = completionHandelr
        
        let productsRequest = SKProductsRequest(productIdentifiers: Set(["productIds"]))
        productsRequest.delegate = self
        productsRequest.start()
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {

        let invalidProducts = response.invalidProductIdentifiers
        for id in invalidProducts {
            print("invalid product ID: \(id)")
        }
        
        let validProducts = response.products
        
        for p in validProducts {
            print("valid Product: 商品ID= \(p.productIdentifier) 商品名=\(p.localizedTitle) 商品説明=\(p.localizedDescription) 価格=\(p.price.floatValue)")
        }
        
        guard validProducts.count > 0 else {
            return
        }
        
        self.productsInfoCompletion?(.Success(validProducts))
    }
    
    func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    private func buyProduct(product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.defaultQueue().addPayment(payment)
    }
    
    func startRestore(completion: PayingResultCompletion) {
        self.payingCompletion = completion
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .Purchased:
                purchasedTransaction(transaction)
                break
            case .Failed:
                failedTransaction(transaction)
                break
            case .Restored:
                restoredTransaction(transaction)
                break
            case .Deferred:
                print("deferred...")
                break
            case .Purchasing:
                print("purchasing...")
                break
            }
        }
    }
    
    private func purchasedTransaction(transaction: SKPaymentTransaction) {
        print("completeTransaction...")
        guard let reciept = self.loadReceiptString() else {
            print("failed loading receipt")
            return
        }

        self.purchaseCompletion?(.Success)
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        
        guard let productIdentifier = queue.transactions[queue.transactions.count-1].originalTransaction?.payment.productIdentifier else { return }
        print("restoreTransaction... \(productIdentifier)")
        
        let transact: SKPaymentTransaction = queue.transactions[queue.transactions.count-1]
        
        guard let reciept = self.loadReceiptString() else {
            return
        }

    }
    
    private func failedTransaction(transaction: SKPaymentTransaction) {
        print("failedTransaction...")
        if transaction.error!.code != SKErrorCode.PaymentCancelled.rawValue {
            print("Transaction Error: \(transaction.error?.localizedDescription)")
        }
        SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    }
    
    func priceStringFromProduct(product: SKProduct!) -> String {
        let numberFormatter = NSNumberFormatter()
        numberFormatter.formatterBehavior = .Behavior10_4
        numberFormatter.numberStyle = .CurrencyStyle
        numberFormatter.locale = product.priceLocale
        return numberFormatter.stringFromNumber(product.price)!
    }
    
    private func loadReceiptString() -> String? {
        
        guard let receiptUrl: NSURL = NSBundle.mainBundle().appStoreReceiptURL else {
            return nil
        }
        
        guard let receiptData: NSData = NSData(contentsOfURL: receiptUrl) else {
            return nil
        }
        
        // Convert to base64 string.
        return receiptData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        
    }
    
}
