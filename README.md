# THIS REPO IS NO LONGER MAINTANED!!

We have migrated our SDK project into swift packages rather than using CocoaPods as our package platform. Please go to https://github.com/QuickPay/ios-sdk to find the newest and maintaned SDK.


# QuickPay SDK


The QuickPay SDK wraps the [QuickPay API](https://learn.quickpay.net/tech-talk/api/services/#services "QuickPay API") and provides the necessary functionality and convenience to add native payments to your app.


## Installation

You can install the QuickPay SDK either by downloading it directly from our GitHub repo or by using CocoaPods. If you want to use CocoaPods you can copy the example Podfile below.

```ruby
platform :ios, '11.0'

target '<YOUR_PROJECT_NAME>' do
  use_frameworks!

  pod 'QuickPaySDK'
end
```


### Fat library

The SDK is built as a fat library meaning it contains symbols for both the simulator and device architectures. This is done so you can develop on both platforms with the same binary without having to mess around with build paths or swapping out binaries. Unfortunately, Apple requires you to remove all simulator related symbols before submitting your app. The easiest way to do this is to add an additional build step that strips the unused architectures. If you don't have a script that does this already you can copy the one provided here. Select your build target, go to `Build Phases` and add a new run script phase. Copy and paste the code below into your script and you will be good to go.

```bash
echo "Target architectures: $ARCHS"

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

find "$APP_PATH" -name '*.framework' -type d | while read -r FRAMEWORK
do
FRAMEWORK_EXECUTABLE_NAME=$(defaults read "$FRAMEWORK/Info.plist" CFBundleExecutable)
FRAMEWORK_EXECUTABLE_PATH="$FRAMEWORK/$FRAMEWORK_EXECUTABLE_NAME"
echo "Executable is $FRAMEWORK_EXECUTABLE_PATH"
echo $(lipo -info "$FRAMEWORK_EXECUTABLE_PATH")

FRAMEWORK_TMP_PATH="$FRAMEWORK_EXECUTABLE_PATH-tmp"

# remove simulator's archs if location is not simulator's directory
case "${TARGET_BUILD_DIR}" in
*"iphonesimulator")
echo "No need to remove archs"
;;
*)
if $(lipo "$FRAMEWORK_EXECUTABLE_PATH" -verify_arch "i386") ; then
lipo -output "$FRAMEWORK_TMP_PATH" -remove "i386" "$FRAMEWORK_EXECUTABLE_PATH"
echo "i386 architecture removed"
rm "$FRAMEWORK_EXECUTABLE_PATH"
mv "$FRAMEWORK_TMP_PATH" "$FRAMEWORK_EXECUTABLE_PATH"
fi
if $(lipo "$FRAMEWORK_EXECUTABLE_PATH" -verify_arch "x86_64") ; then
lipo -output "$FRAMEWORK_TMP_PATH" -remove "x86_64" "$FRAMEWORK_EXECUTABLE_PATH"
echo "x86_64 architecture removed"
rm "$FRAMEWORK_EXECUTABLE_PATH"
mv "$FRAMEWORK_TMP_PATH" "$FRAMEWORK_EXECUTABLE_PATH"
fi
;;
esac

echo "Completed for executable $FRAMEWORK_EXECUTABLE_PATH"
echo $(lipo -info "$FRAMEWORK_EXECUTABLE_PATH")

done
```


### API key and permissions

In order for the SDK to communicate with QuickPay, you will need an API key. You can create one by logging in to your QuickPay account and navigate to Settings -> Users. The API key you use with the SDK needs some additional permissions in order to work with Apple Pay, MobilePay and Vipps. Select the user to which the API key belongs and add the following permissions.

```html
GET  /acquirers/clearhaus   (Apple Pay)
GET  /acquirers/mobilepay   (MobilePay)
GET  /acquirers/vipps       (Vipps)
POST /payments/:id/session  (MobilePay + Vipps)
```


## Usage

This guide will take you through the steps needed to integrate the QuickPay SDK with your code and demonstrate how to make basic payments with the different payment methods the SDK supports.


### Initialization

In your AppDelegate, you need to initialize the SDK with your API key.
```swift
QuickPay.initWith(apiKey: String)
```

As soon as you pass your API key to the SDK, it will begin to communicate with the QuickPay API in order to determine which payment methods that are available for the given API key. You can ask the SDK if it is done initializing by looking at the `isInitializing` property. If the property is true it means that the SDK is currently communicating with the QuickPay API. If you don't want to observe this property you can instead attach an `InitializeDelegate` to the QuickPay class. This will notify you when the SDK begins the initialization and when it is completed.


### Payment flow

To make a payment and authorize it you need to follow these four steps
1. Create a payment
2. Create a payment session
3. Authorize the payment
4. Check the payment status to see if the authorization went well

All payments need to go through these four steps but some services, like the payment window, will handle multiple of these steps in one request.


### Payment Window

The payment windows are the easiest and quickest way to get payments up and running, it is currently also the only way you can accept payments with credit cards through the QuickPay SDK. The payment window handles step 2 and 3 of the payment flow for you, so the order of operations looks like this.

1. Create payment
2. Generate a payment URL and display the payment window
3. Check the payment status

To create a payment you first need to specify some parameters which are wrapped in the `QPCreatePaymentParameters` class. Afterward, you pass the parameters to the constructor of a `QPCreatePaymentRequest`. Last you need to send the request to QuickPay, this is done with the `sendRequest` function on the request itself which requires a success and failure handler.

```swift
let params = QPCreatePaymentParameters(currency: "DKK", order_id: "SomeOrderId")
let request = QPCreatePaymentRequest(parameters: params)

request.sendRequest(success: { (payment) in
    // Handle the payment
}, failure: { (data, response, error) in
    // Handle the failure
})
```

If this succeeds a `QPPayment` will be given to you in the success handler. The next step is to generate a payment URL that you will need in order to display the web-based payment window. The needed parameters for this request are wrapped in `QPCreatePaymentLinkParameters` and is needed in the constructor of a `QPCreatePaymentLinkRequest`. The parameters need a payment id and the amount it needs to authorize. Send the request and wait for the response.

```swift
let linkParams = QPCreatePaymentLinkParameters(id: payment.id, amount: 100)
let linkRequest = QPCreatePaymentLinkRequest(parameters: linkParams)

linkRequest.sendRequest(success: { (paymentLink) in
    // Handle the paymentLink
}, failure: { (data, response, error) in
    // Handle the failure
})
```

The last step is to use the `QPPaymentLink` to open the payment window and here you have two choices. You can either use a build-in convenience mechanism that will display the payment window and handle the interaction and responses for you, or you can handle that yourself and get full flexibility on how you want to present the payment window.

If you want to use the convenience mechanism you will have to pass the payment url to the QuickPay class. With the Presentation enum you can specify whether you want to push or present the payment window.

```swift
QuickPay.openPaymentLink(paymentUrl: paymentLink.url, onCancel: {
    // Handle if the user cancels
}, onResponse: { (success) in
    // Handle success/failure
}, presentation: .present(controller: self, animated: true, completion: nil))
```

If success is true the payment has been handled but we do not yet know if the payment has been authorized. For that, we need to check the status of the payment which is done with the `QPGetPaymentRequest`.

```swift
QPGetPaymentRequest(id: payment.id).sendRequest(success: { (payment) in
    if payment.accepted {
        // The payment has been authorized 👍
    }
}, failure: { (data, response, error) in
    // Handle the failure
})
```

If you want more control of the payment window and want to handle the navigation yourself, you can create a `QPPaymentWindowController` and pass the payment url in its initializer. Next, you set a `QPPaymentWindowControllerDelegate` to the payment window controller and you can now have full control over how to present the payment view. Through the delegate, you can also create a custom loading view that will be shown while the payment window is getting loaded and rendered.


### MobilePay

QuickPay SDK supports MobilePay natively so you can create a great app experience. To query the MobilePay App you need to make some changes to your project settings and implement the payment as shown later in this guide.

It is recommended that you check if the users have the MobilePay App installed and only show the payment option if it is available. The QuickPay class can help you with this.

```swift
QuickPay.isMobilePayAvailable()
```


#### URL Schemes for MobilePay

To query the MobilePay App you need to whitelist the `mobilepayonline` URL scheme to the `LSApplicationQueriesSchemes` array in your `Info.plist`. With this done your application can now query the MobilePay App with the needed information for MobilePay to handle the authorization of a payment.

You also need to specify a custom URL scheme for the MobilePay App to query back to when it is done doing its job. This is done in the `URL types` array in your `Info.plist`.

You can read more about the URL schemes on [https://developers.apple.com](https://developer.apple.com/documentation/uikit/core_app/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app)


#### Payment flow for MobilePay

First, you need to create a payment just like with the payment window, but after that, the flow is different since we do not have the payment window to handle a lot of tasks for us.

When you have created your payment you need to start a MobilePay payment session. Create a `MobilePayParameters` object and specify the custom URL scheme that you created earlier. You can also specify the language of MobilePay and add a URL to a logo you want it to be displayed. Add this information to a `QPCreatePaymenSessionParameters` along with the amount of money you want to authorize. Finally, put everything together in a `QPCreatePaymenSessionRequest` and send the request.

```swift
let mobilePayParameters = MobilePayParameters(returnUrl: "quickpayexampleshop://", language: "dk", shopLogoUrl: "https://SomeUrl/SomeImage.png")
let sessionParameters = QPCreatePaymenSessionParameters(amount: 100, mobilePay: mpp)

let request = QPCreatePaymenSessionRequest(id: payment.id, parameters: sessionParameters)

request.sendRequest(success: { (payment) in
    // Handle the payment
}, failure: { (data, response, error) in
    // Handle the failure
})
```

With the payment containing a session id, we can now query MobilePay to authorize the payment.

```swift
QuickPay.authorizeWithMobilePay(payment: payment, completion: { (payment) in {
    // Handle the payment
}, failure: {
    // Handle the failure
}
```

In the completion handler, we need to check the status of the payment. This is done in the same way as with the payment window. Create a `QPGetPaymentRequest` with the payment id and check if the updated payment is accepted.


### Apple Pay

In order to take advantage of Apple Pay, first, you need to do some initial setup to your project and generate a signing certificate. When that is done you also need to implement a bit of code to handle the native Apple Pay flow.

NOTE: You will need an agreement with Clearhaus in order to use Apple Pay


#### Certificates

In order for Apple to encrypt the payments, you will need a certificate created by Apple and upload it to your QuickPay account.


##### Obtaining a certificate signing request (CSR)

Login to your QuickPay account and navigate to Settings -> Acquirers -> Clearhaus. Here you will need to enable Apple Pay and click on `CREATE A CERTIFICATE`. Create a new key by choosing ApplePay as the type and type in a short description. Choose your newly generated key, click `CREATE CSR`, fill out the form and click `CREATE`. You will now download the CSR (.pem file) which you need to take to your Apple developer account. Don't bother closing this window because you will need it again in a moment.


##### Merchant Id and certificates

Log in to your Apple developer account and navigate to `Certificates, Identifiers & Profiles`. Choose `Merchant IDs` and generate a new Merchant id. Now edit your Merchant Id and choose `Create Certificate`. Follow the guide and upload the CSR from QuickPay. This will generate a certificate for you. Download the certificate and go back to the QuickPay window to upload the certificate.


##### Add the merchant id to your app

Now open XCode and go to your target capabilities. Enable Apple Pay and choose the Merchant Id you just created. You will need the identifier of your merchant id late in this guide so either remember it or write it down.


#### Payment flow for Apple Pay

Now that you have created a Merchant Id and a certificate you are ready to add the code necessary. Since most of the code needed is dictated by Apple and PassKit only the QuickPay specific code will be covered here. You will be able to find great resources and guides on the internet on how to implement Apple Pay in your code. We recommend [this guide](https://www.weareintersect.com/news-and-insights/better-guide-setting-apple-pay/) but almost any guide will do. You can also take a look in the QuickPay example app to see how it is implemented.

When your ViewController conforms to the `PKPaymentAuthorizationViewControllerDelegate` protocol there are two functions we need to take a look at in order to write the QuickPay specific code.

The first function is where Apple needs QuickPay to authorize the payment.
```swift
func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void)
```

The way we accomplish this is by creating a payment at QuickPay just like with the other payment methods. Then we need to authorize it with a card that contains the payment token stored in the PKPayment that is provided by Apple. When we get a response from QuickPay we need to tell PassKit that the authorization is done and whether it was a success or a failure.

```swift
let authParams = QPAuthorizePaymentParams(id: qpPayment.id, amount: 100)
authParams.card = QPCard(applePayToken: pkPayment.token)

let authRequest = QPAuthorizePaymentRequest(parameters: authParams)

authRequest.sendRequest(success: { (qpPayment) in
   completion(PKPaymentAuthorizationResult.init(status: .success, errors: nil))
}, failure: { (data, response, error) in
  completion(PKPaymentAuthorizationResult.init(status: .failure, errors: nil))
})
```

The last function to handle is the one that tells us that the payment flow is finished. This will be called no matter if the payment was a success or a failure. This is the place where we need to validate if the payment was successfully authorized or not.

```swift
func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController)
```


## Payment UI

If you don't want to spend too much time on making your own UI for a payment selection, the SDK comes bundles with a UI component you can use. The payment view will automatically determine which payment options are available through the QuickPay API and will also check which payment apps are available on the user's phone. This payment view is used in the example app.

The payment component is named `PaymentView` and can be found in the `QuickPaySDK` module.


### Use with Storyboards

To attach the PaymentView to your Storyboard, drag in a UIView and go to the identity inspector. Change the class to PaymentView and the module to QuickPaySDK. Add the PaymentView as an outlet to your UIViewController so we can make some additional setup in the code.

If you are using layout constraints be aware that the PaymentView overrides the intrinsicContentSize function and thereby calculates its own height. This means that it is not necessary to add a height constraint to the PaymentView, but XCode will throw warnings if there is none. Therefore add a height constraint of whatever and set the priority to low (<250).

At this point, the PaymentComponent is ready to use, but you won't know when or if a user has selected a payment method. Here the `PaymentViewDelegate` comes into play. The PaymentViewDelegate has two functions. First it will notify when the user selects a payment method, secondly, it is used to determine the text that will be displayed in the payment method cells. In the code, you can conform to the PaymentViewDelegate and then attach it to the PaymentView.

```swift
extension ShopViewController: PaymentViewDelegate {

    func titleForPaymentMethod(_ paymentView: PaymentView, paymentMethod: PaymentView.PaymentMethod) -> String {
        // If you want to use the default English titles, the PaymentMethod enum as a default title.
        return paymentMethod.defaultTitle()
    }

    func didSelectPaymentMethod(_ paymentView: PaymentView, paymentMethod: PaymentView.PaymentMethod) {
        // The user has selected a payment method.
        // This is useful if you want to change a payment button from disabled to enabled or show some additional information
        // about the selected payment method.
    }

}
```


### Initialization

The QuickPay SDK needs to have completed its initialization phase before you display the PaymentView.


### Styling

The cells used by the payment component has some basic color styling properties so you can make it match your theme. The options available are marked as IBInspectable and can be accessed directly in the StoryBoard. You can also change them through your code.

These are the properties available
 - cellBackgroundColorSelected
 - cellBackgroundColorUnselected
 - cellBorderColorSelected
 - cellBorderColorUnselected
