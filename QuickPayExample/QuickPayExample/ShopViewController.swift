//
//  ShowViewController.swift
//  QuickPayExample
//
//  Created on 14/01/2019.
//  Copyright © 2019 QuickPay. All rights reserved.
//
//  This ViewController is ment to demonstrate how the different payment methods can be used.
//  Please note that there are many more payment options than what is demonstrated here
//  and you should read the technical documentation at the QuickPay website in order to get
//  a better understanding of all the possibilities.
//  https://learn.quickpay.net/tech-talk/
//
//  WARNING:
//  This example app does not handle complex scenarios like if the view is unloaded due to memory management.
//  Therefore you should only look at this code as inspiration and not a final solution.

import QuickPaySDK
import PassKit

class ShopViewController: UIViewController {
    
    // MARK: - Properties
    
    // The id of the current payment that is being processed.
    var currentPaymentId: Int?
    
    // Basket
    let tshirtPrice = 0.5
    let footballPrice = 1.0
    var tshirtCount = 0
    var footballCount = 0
    
    
    // MARK: Outlets
    @IBOutlet weak var basketThshirtLabel: UILabel!
    @IBOutlet weak var basketTshirtTotalLabel: UILabel!
    @IBOutlet weak var basketTshirtSection: UIStackView!
    
    @IBOutlet weak var basketFootballLabel: UILabel!
    @IBOutlet weak var basketFootballTotalLabel: UILabel!
    @IBOutlet weak var basketFootballSection: UIStackView!
    
    @IBOutlet weak var basketTotalLabel: UILabel!
    
    @IBOutlet weak var paymentButton: UIButton!
    @IBOutlet weak var paymentView: PaymentView!
    
    
    // MARK: - IBActions
    
    @IBAction func tshirtCountChanged(_ sender: UIStepper) {
        tshirtCount = Int(sender.value)
        updateBasket()
    }
    
    @IBAction func footballCountChanged(_ sender: UIStepper) {
        footballCount = Int(sender.value)
        updateBasket()
    }

    @IBAction func handlePayment(_ sender: Any) {
        guard !isBasketEmpty() else {
            displayOkAlert(title: "Basket is empty", message: "Your basket is empty. Please add some items before paying.")
            return
        }
        
        if let paymentOption = paymentView.getSelectedPaymentOption() {
            switch paymentOption {
            case .paymentcard:
                handlePaymentWindow()
                break
                
            case .applepay:
                handleApplePay()
                break
            }
        }
    }
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Style the navigation bar
        let navigationBarImage = UIImageView(image: UIImage(named: "Logo Inverse"))
        navigationBarImage.contentMode = .scaleAspectFit
        navigationItem.titleView = navigationBarImage

        paymentView.delegate = self
        QuickPay.initializeDelegate = paymentView
        paymentButton.isEnabled = false
        
        updateBasket()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.removeSpinner()
    }

    
    // MARK: - UI
    
    private func updateBasket() {
        // Update the TShirt section
        basketThshirtLabel.text = "T-Shirt  x \(tshirtCount)"
        basketTshirtTotalLabel.text = "\(Double(tshirtCount) * tshirtPrice) DKK"
        
        // Update the football sections
        basketFootballLabel.text = "Football x \(footballCount)"
        basketFootballTotalLabel.text = "\(Double(footballCount) * footballPrice) DKK"
        
        // Update the total section
        basketTotalLabel.text = "\(totalBasketValue()) DKK"
    }
    
    
    // MARK: - Utils
    
    private func createPaymentParametersFromBasket() -> QPCreatePaymentParameters {
        // Create the params needed for creating a payment
        let params = QPCreatePaymentParameters(currency: "DKK", order_id: String.randomString(len: 20))
        params.text_on_statement = "QuickPay Example Shop"
        
        let invoiceAddress = QPAddress()
        invoiceAddress.name = "Some Street"
        invoiceAddress.city = "Aarhus"
        invoiceAddress.country_code = "DNK"
        params.invoice_address = invoiceAddress
        
        // Fill the basket with the tshirts and footballs
        let tshirtBasket =   QPBasket(qty: tshirtCount, item_no: "1", item_name: "T-Shirt", item_price: tshirtPrice, vat_rate: 0.25)
        let footballBasket = QPBasket(qty: footballCount, item_no: "2", item_name: "Football", item_price: footballPrice, vat_rate: 0.25)
        params.basket?.append(tshirtBasket)
        params.basket?.append(footballBasket)

        return params
    }

    private func createSubscriptionParametersFromBasket() -> QPCreateSubscriptionParameters {
        // Create the params needed for creating a payment
        let params = QPCreateSubscriptionParameters(currency: "DKK", order_id: String.randomString(len: 20), description: "Some description")
        params.text_on_statement = "QuickPay Example Shop"

        let invoiceAddress = QPAddress()
        invoiceAddress.name = "Some Street"
        invoiceAddress.city = "Aarhus"
        invoiceAddress.country_code = "DNK"
        params.invoice_address = invoiceAddress
        
        // Fill the basket with the tshirts and footballs
        let tshirtBasket =   QPBasket(qty: tshirtCount, item_no: "1", item_name: "T-Shirt", item_price: tshirtPrice, vat_rate: 0.25)
        let footballBasket = QPBasket(qty: footballCount, item_no: "2", item_name: "Football", item_price: footballPrice, vat_rate: 0.25)
        params.basket?.append(tshirtBasket)
        params.basket?.append(footballBasket)
        
        return params
    }
    
    private func handleQuickPayNetworkErrors(data: Data?, response: URLResponse?, error: Error?) {
        if let data = data {
            print(String(data: data, encoding: String.Encoding.utf8)!)
        }
        
        if let error = error {
            print(error)
        }
        
        if let response = response {
            print(response)
        }
        
        displayOkAlert(title: "Request failed", message: error?.localizedDescription ?? "Unknown error")
    }
    
    private func totalBasketValue() -> Double {
        return Double(tshirtCount) * tshirtPrice + Double(footballCount) * footballPrice
    }
    
    private func isBasketEmpty() -> Bool {
        if tshirtCount == 0 && footballCount == 0 {
            return true;
        }
        else {
            return false;
        }
    }
    
}


// MARK: - Apple Pay
/**
 Example code to demonstrate the use of Apple Pay
 
 Apple Pay is a bit different from the other payment methods since Apple handles most of the payment process.
 We recommend you to read this article that descripes all the posibilities you have with Apple Pay.
 https://www.weareintersect.com/news-and-insights/better-guide-setting-apple-pay/
 
 The steps needed to use Apple Pay is
 1) Create a PKPaymentRequest that we can send to Apple
 2) Init the Apple Pay controller with the payment and display it
 3) Create a payment
 4) Authorize the payment with the token stored in the PKPayment
 5) Validate that the authoprization went well
 
 NOTE: YOU WILL NOT BE ABLE TO COMPLETE A PAYMENT WITH APPLE PAY IN THIS EXAMPLE APP WITHOUT A VALID SIGNING CERTIFICATE!!
 */
extension ShopViewController: PKPaymentAuthorizationViewControllerDelegate {
    
    func handleApplePay() {
        // Test if Apple Pay is available on the phone
        if !PKPaymentAuthorizationViewController.canMakePayments() {
            displayOkAlert(title: "Error", message: "Sorry but Apple Pay is not supported on your iPhone")
        }

        // Define the type of payment cards that can be used
        let networks = [PKPaymentNetwork.visa, PKPaymentNetwork.masterCard, PKPaymentNetwork.JCB]
        let merchantCapabilities = PKMerchantCapability.capability3DS
        
        // Test if the users wallet has a compatible payment card
        if !PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: merchantCapabilities) {
            PKPassLibrary().openPaymentSetup()
            return;
        }

        // Step 1) Create a PKPaymentRequest that we can send to Apple
        let request = PKPaymentRequest()

        // This merchantIdentifier should have been created for you in Xcode when you set up the Apple Pay capabilities.
        request.merchantIdentifier = "merchant.quickpayexample"
        request.countryCode = "DK" // Standard ISO country code. The country in which you make the charge.
        request.currencyCode = "DKK" // Standard ISO currency code. Any currency you like.
        request.supportedNetworks = networks
        request.merchantCapabilities = merchantCapabilities
        
        // Add the items for the summary that will be displayed to the user
        request.paymentSummaryItems = []
        
        if tshirtCount > 0 {
            request.paymentSummaryItems.append(PKPaymentSummaryItem(label: "\(tshirtCount) T-Shirt\(tshirtCount > 1 ? "s" : "")", amount: NSDecimalNumber(floatLiteral: Double(tshirtCount)*tshirtPrice)))
        }
        
        if footballCount > 0 {
            request.paymentSummaryItems.append(PKPaymentSummaryItem(label: "\(footballCount) Football\(footballCount > 1 ? "s" : "")", amount: NSDecimalNumber(floatLiteral: Double(footballCount)*footballPrice)))
        }

        request.paymentSummaryItems.append(PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(floatLiteral: totalBasketValue())))
        
        // Step 2) Init the Apple Pay controller with the payment and display it
        if let applePayController = PKPaymentAuthorizationViewController(paymentRequest: request) {
            applePayController.delegate = self
            self.present(applePayController, animated: true, completion: nil)
        }
        else {
            displayOkAlert(title: "Error", message: "We could not display the Apple Pay window")
        }
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Step 3) Create a payment
        QPCreatePaymentRequest(parameters: createPaymentParametersFromBasket()).sendRequest(success: { (qpPayment) in
            self.currentPaymentId = qpPayment.id
            
            // Step 4) Authorize the payment with the token stored in the PKPayment
            let authParams = QPAuthorizePaymentParams(id: qpPayment.id, amount: Int(self.totalBasketValue() * 100))
            authParams.card = QPCard(applePayToken: payment.token)
            
            let authRequest = QPAuthorizePaymentRequest(parameters: authParams)
            
            authRequest.sendRequest(success: { (qpPayment) in
                // When we are done with the authorization we need to manually invoke the completion handler to signal that we are done
                completion(PKPaymentAuthorizationResult.init(status: .success, errors: nil))
            }, failure: { (data, response, error) in
                self.handleQuickPayNetworkErrors(data: data, response: response, error: error)
                completion(PKPaymentAuthorizationResult.init(status: .failure, errors: nil))
            })
        }) { (data, response, error) in
            self.handleQuickPayNetworkErrors(data: data, response: response, error: error)
            completion(PKPaymentAuthorizationResult.init(status: .failure, errors: nil))
        }
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        if let paymentId = currentPaymentId {
            self.currentPaymentId = nil

            // Step 5) Validate that the authoprization went well
            QPGetPaymentRequest(id: paymentId).sendRequest(success: { (qpPayment) in
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                    
                    if qpPayment.accepted {
                        self.displayOkAlert(title: "Payment Accepted", message: "The payment was accepted and the acquirer is \(qpPayment.acquirer ?? "unknown")")
                        // Congratulations, you have successfully authorized the payment.
                        // You can now capture the payment when you have shipped the items.
                    }
                    else {
                        self.displayOkAlert(title: "Payment Not Accepted", message: "The payment was not accepted")
                    }
                }
            }) { (data, response, error) in
                self.dismiss(animated: true, completion: nil)
            }
        }
        else {
            self.dismiss(animated: true, completion: nil)
            self.displayOkAlert(title: "Payment Not Accepted", message: "The payment was not accepted")
        }
    }
    
}


// MARK: - Payment Window
/**
 Example code to demonstrate the use of the Payment Window
 
 The steps needed to use the Payment Window is
 1) Create a payment
 2) Create a payment URL
 3) Open the payment URL in a WebView (the SDK handles this part for you)
 4) Validate that the authoprization went well
 */
extension ShopViewController {
    
    func handlePaymentWindow() {
        showSpinner(onView: self.view)

        // Step 1) Create a payment
        QPCreatePaymentRequest(parameters: createPaymentParametersFromBasket()).sendRequest(success: { (payment) in
            // Step 2) Create a payment URL
            let linkParams = QPCreatePaymentLinkParameters(id: payment.id, amount: self.totalBasketValue() * 100.0)
            linkParams.payment_methods = "creditcard"
            
            QPCreatePaymentLinkRequest(parameters: linkParams).sendRequest(success: { (paymentLink) in
                QuickPay.logDelegate?.log("Payment Link: \(paymentLink.url)")
                
                // Step 3) Open the payment URL in a WebView
                QuickPay.openPaymentLink(paymentUrl: paymentLink.url, onCancel: {
                    self.displayOkAlert(title: "Payment Cancelled", message: "The payment was cancelled")
                }, onResponse: { (success) in
                    // Step 4) Validate that the authoprization went well
                    QPGetPaymentRequest(id: payment.id).sendRequest(success: { (payment) in
                        if payment.accepted {
                            self.displayOkAlert(title: "Payment Accepted", message: "The payment was accepted and the acquirer is \(payment.acquirer ?? "unknown")")
                            // Congratulations, you have successfully authorized the payment.
                            // You can now capture the payment when you have shipped the items.
                        }
                        else {
                            self.displayOkAlert(title: "Payment Not Accepted", message: "The payment was not accepted")
                        }
                    }, failure: self.handleQuickPayNetworkErrors)
                }, presentation: .present(controller: self, animated: true, completion: nil))
            }, failure: self.handleQuickPayNetworkErrors)
        }, failure: self.handleQuickPayNetworkErrors)
    }
}


// MARK: - PaymentViewDelegate
extension ShopViewController: PaymentViewDelegate {
    
    func titleForPaymentMethod(_ paymentView: PaymentView, paymentMethod: PaymentView.PaymentMethod) -> String {
        return paymentMethod.defaultTitle()
    }
    
    func didSelectPaymentMethod(_ paymentView: PaymentView, paymentMethod: PaymentView.PaymentMethod) {
        paymentButton.isEnabled = true
    }
    
}
