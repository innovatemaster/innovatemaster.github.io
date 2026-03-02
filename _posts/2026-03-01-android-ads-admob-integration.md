---
layout: post
title: "Integrating Ads into an Android App with Google AdMob: A Complete Guide"
date: 2026-03-01 14:00 +0100
categories: [Android, Monetization]
tags: [android, java, gradle, admob, ads, banner, interstitial, rewarded, native-ads, google-play, monetization]
description: A step-by-step guide to integrating Google AdMob advertisements into a native Android app written in Java, covering SDK setup, banner ads, interstitial ads, rewarded ads, native ads, testing, mediation, and Google Play policy compliance.
---

# Integrating Ads into an Android App with Google AdMob

Monetizing an Android app through advertising is one of the most common revenue strategies for free-to-play apps. Google AdMob is the dominant ad platform for mobile, offering high fill rates, multiple ad formats, and tight integration with the Android ecosystem.

This guide walks through the full process of adding ads to a **native Android app written in Java**, built with Gradle. It covers SDK setup, every major ad format, testing, mediation, and the policy requirements you must meet before publishing to the Google Play Store.

> **Prerequisite:** This guide assumes you already have a working Android project and are familiar with building and running it. If you need help getting your app onto the Play Store, see [Deploy a Native Android App to the Google Play Store](/android/devops/2026/03/01/deploy-android-app-google-play-store.html).

## 1. Create an AdMob Account and Register Your App

Before writing any code, you need an AdMob account and at least one ad unit.

1. Go to [AdMob](https://admob.google.com/) and sign in with your Google account.
2. Click **Apps > Add app**.
3. Select **Android** as the platform.
4. If your app is already on the Play Store, search for it. Otherwise, select **No, it's not listed on a supported app store** and enter the app name manually.
5. Note the **App ID** that AdMob assigns (format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`). You will need this in your manifest.
6. Create one or more **Ad Units** (banner, interstitial, rewarded, or native). Each ad unit has its own ID (format: `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`).

> Create **separate ad units for each placement** in your app, even if they use the same format. For example, if you have banner ads on three different screens, create three banner ad units. This gives you per-placement analytics in the AdMob dashboard and lets you A/B test eCPM floors independently.
{: .prompt-tip }

## 2. Add the Google Mobile Ads SDK

### Update the Project-Level build.gradle

Make sure Google's Maven repository is included. Most modern projects already have this through the `google()` shorthand:

```groovy
// settings.gradle (or project-level build.gradle depending on your setup)
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

### Add the SDK Dependency

In your **module-level** `build.gradle`:

```groovy
dependencies {
    implementation 'com.google.android.gms:play-services-ads:23.6.0'
}
```

After adding the dependency, sync your project with Gradle.

> This guide uses Java, but the Mobile Ads SDK works identically with Kotlin. If you are using Jetpack Compose, Google provides Compose-specific helpers for banner ads through the `com.google.android.gms:play-services-ads-lite` artifact, though the full SDK is still needed for interstitial, rewarded, and native formats.
{: .prompt-info }

> **Versioning:** Always check the [Google Mobile Ads SDK release notes](https://developers.google.com/admob/android/rel-notes) for the latest version. The SDK follows semantic versioning and newer versions include bug fixes, new ad formats, and policy compliance updates.

### Set the compileSdk

The Mobile Ads SDK requires a recent `compileSdk`. As of version 23.x, `compileSdk 34` or higher is required:

```groovy
android {
    compileSdk 35

    defaultConfig {
        minSdk 21
        targetSdk 35
        // ...
    }
}
```

## 3. Configure the AndroidManifest

### Add the AdMob App ID

The SDK requires your AdMob App ID as a `<meta-data>` element inside the `<application>` tag. **This is not the ad unit ID** -- it is the app-level ID you got from the AdMob dashboard.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.MyApp">

        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" />

        <!-- Activities, services, etc. -->
    </application>
</manifest>
```

If you omit the `APPLICATION_ID` meta-data, the app will crash at startup with an `IllegalStateException`.

> Avoid hardcoding the App ID directly in the manifest. Instead, store it in `gradle.properties` (e.g., `ADMOB_APP_ID=ca-app-pub-XXX~YYY`) and reference it in `build.gradle` via `manifestPlaceholders`, then use `${ADMOB_APP_ID}` in the manifest. This keeps sensitive identifiers out of version control and makes it easier to manage different IDs across build variants.
{: .prompt-tip }

### Optional: Ad Network Security Configuration

Starting with Android 9 (API 28), cleartext HTTP traffic is blocked by default. The Mobile Ads SDK and mediation partners may require it for certain ad creatives. If you encounter ad loading failures, add a network security config:

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

Then reference it in the manifest:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ... >
```

> Enabling cleartext globally is a broad permission. In production, prefer domain-specific rules that only allow cleartext for known ad-serving domains.
{: .prompt-warning }

## 4. Initialize the Mobile Ads SDK

Initialize the SDK once, early in your app's lifecycle -- typically in your `Application` class or the `onCreate()` of your main `Activity`. Initialization is asynchronous.

```java
import com.google.android.gms.ads.MobileAds;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        MobileAds.initialize(this, initializationStatus -> {
            // SDK is ready -- you can now load ads
        });
    }
}
```

The `initializationStatus` object contains the status of each ad network adapter (useful when mediation is enabled). You can log these statuses during development to verify that adapters initialized correctly.

> `MobileAds.initialize()` must be called on the **main thread**. Calling it from a background thread will throw an exception or silently fail to initialize adapters.
{: .prompt-warning }

## 5. Banner Ads

Banner ads are rectangular ads that occupy a portion of the screen. They refresh automatically and are the simplest format to integrate.

### Add an AdView to Your Layout

```xml
<!-- res/layout/activity_main.xml -->
<LinearLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:ads="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <!-- Your app content above -->

    <com.google.android.gms.ads.AdView
        android:id="@+id/adView"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="center_horizontal"
        ads:adSize="BANNER"
        ads:adUnitId="ca-app-pub-3940256099942544/6300978111" />

</LinearLayout>
```

The ad unit ID in the example above is a **Google-provided test ID**. Never use your production ad unit ID during development.

### Load the Banner Ad in Java

```java
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdView;

public class MainActivity extends AppCompatActivity {

    private AdView adView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        MobileAds.initialize(this, initializationStatus -> {});

        adView = findViewById(R.id.adView);
        AdRequest adRequest = new AdRequest.Builder().build();
        adView.loadAd(adRequest);
    }

    @Override
    protected void onPause() {
        if (adView != null) adView.pause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (adView != null) adView.resume();
    }

    @Override
    protected void onDestroy() {
        if (adView != null) adView.destroy();
        super.onDestroy();
    }
}
```

Calling `pause()`, `resume()`, and `destroy()` on the `AdView` lifecycle methods prevents memory leaks and unnecessary background activity.

> Banner ads typically yield the **lowest eCPM** of all formats (often $0.10--$1.00 for most regions). They work best as a baseline revenue layer combined with higher-value formats like rewarded or interstitial ads. If banners are your only ad format, you will need very high daily active users to generate meaningful revenue.
{: .prompt-info }

### Adaptive Banner Ads

Fixed-size banners (`BANNER`, `LARGE_BANNER`, `MEDIUM_RECTANGLE`) have predefined dimensions. For a better experience on varying screen sizes, use **adaptive banners** which automatically adjust width:

```java
import com.google.android.gms.ads.AdSize;

private AdSize getAdaptiveBannerSize() {
    DisplayMetrics displayMetrics = getResources().getDisplayMetrics();
    int adWidthPixels = displayMetrics.widthPixels;
    float density = displayMetrics.density;
    int adWidth = (int) (adWidthPixels / density);
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(this, adWidth);
}
```

Then set it programmatically:

```java
adView.setAdSize(getAdaptiveBannerSize());
adView.setAdUnitId("ca-app-pub-3940256099942544/9214589741");
```

## 6. Interstitial Ads

Interstitial ads are full-screen ads that cover the entire interface. They are typically shown at natural transition points -- between levels in a game, after completing an action, or when navigating between screens.

### Load an Interstitial

```java
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.FullScreenContentCallback;

public class GameActivity extends AppCompatActivity {

    private InterstitialAd interstitialAd;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_game);

        loadInterstitialAd();
    }

    private void loadInterstitialAd() {
        AdRequest adRequest = new AdRequest.Builder().build();

        InterstitialAd.load(this,
            "ca-app-pub-3940256099942544/1033173712",
            adRequest,
            new InterstitialAdLoadCallback() {
                @Override
                public void onAdLoaded(InterstitialAd ad) {
                    interstitialAd = ad;
                    setupFullScreenCallbacks();
                }

                @Override
                public void onAdFailedToLoad(LoadAdError loadAdError) {
                    interstitialAd = null;
                    Log.w("Ads", "Interstitial failed to load: " + loadAdError.getMessage());
                }
            });
    }

    private void setupFullScreenCallbacks() {
        interstitialAd.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override
            public void onAdDismissedFullScreenContent() {
                interstitialAd = null;
                loadInterstitialAd(); // Preload the next one
            }

            @Override
            public void onAdFailedToShowFullScreenContent(com.google.android.gms.ads.AdError adError) {
                interstitialAd = null;
            }
        });
    }

    public void onLevelComplete() {
        if (interstitialAd != null) {
            interstitialAd.show(this);
        } else {
            proceedToNextLevel();
        }
    }

    private void proceedToNextLevel() {
        // Navigate to the next level
    }
}
```

### Interstitial Best Practices

- **Preload early, show later.** Call `load()` well before you need to display the ad. Loading takes time and depends on network conditions.
- **Never show on app launch.** Google policies prohibit interstitials that appear before the user has interacted with the app.
- **Show at natural breaks.** Placing ads at transition points (between levels, after completing a task) reduces user frustration.
- **Don't show too frequently.** A common guideline is no more than one interstitial every 2-3 minutes of active use.
- **Always preload the next ad** in `onAdDismissedFullScreenContent()`.

> Interstitials are a double-edged sword. They generate 10--20x more revenue per impression than banners, but aggressive placement is the number one reason users uninstall ad-supported apps. Track your **Day 1 and Day 7 retention rates** before and after adding interstitials. If retention drops noticeably, reduce frequency or move them to less disruptive transition points.
{: .prompt-warning }

## 7. Rewarded Ads

Rewarded ads give users a choice: watch a full-screen video ad in exchange for an in-app reward (extra lives, virtual currency, premium content access). They have the highest eCPM of any standard format because users opt in voluntarily.

### Load and Show a Rewarded Ad

```java
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.OnUserEarnedRewardListener;
import com.google.android.gms.ads.rewarded.RewardItem;

public class StoreActivity extends AppCompatActivity {

    private RewardedAd rewardedAd;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_store);

        loadRewardedAd();

        findViewById(R.id.btnWatchAd).setOnClickListener(v -> showRewardedAd());
    }

    private void loadRewardedAd() {
        AdRequest adRequest = new AdRequest.Builder().build();

        RewardedAd.load(this,
            "ca-app-pub-3940256099942544/5224354917",
            adRequest,
            new RewardedAdLoadCallback() {
                @Override
                public void onAdLoaded(RewardedAd ad) {
                    rewardedAd = ad;
                }

                @Override
                public void onAdFailedToLoad(LoadAdError loadAdError) {
                    rewardedAd = null;
                    Log.w("Ads", "Rewarded ad failed to load: " + loadAdError.getMessage());
                }
            });
    }

    private void showRewardedAd() {
        if (rewardedAd != null) {
            rewardedAd.show(this, rewardItem -> {
                int rewardAmount = rewardItem.getAmount();
                String rewardType = rewardItem.getType();
                grantReward(rewardType, rewardAmount);
            });
        } else {
            Log.d("Ads", "Rewarded ad not ready yet");
        }
    }

    private void grantReward(String type, int amount) {
        // Credit the user's account with the reward
        // Persist this server-side if the reward has real value
    }
}
```

### Server-Side Verification

For rewards with real monetary value (virtual currency that can be purchased), rely on **server-side verification** (SSV) rather than trusting the client. AdMob can send a callback to your server when a user earns a reward:

```java
import com.google.android.gms.ads.rewarded.ServerSideVerificationOptions;

ServerSideVerificationOptions options = new ServerSideVerificationOptions.Builder()
    .setCustomData("userId=12345")
    .build();

rewardedAd.setServerSideVerificationOptions(options);
```

Configure the SSV callback URL in the AdMob dashboard. Google sends a signed request to your server, which you verify using Google's public key. This prevents users from faking rewards by modifying the client.

> Rewarded ads consistently deliver the **highest eCPM** across all standard ad formats -- often 3--10x higher than interstitials -- because user engagement is voluntary and completion rates are high. If your app has any concept of "lives," "hints," "skips," or "premium content previews," a rewarded ad placement there is likely your single highest-revenue opportunity.
{: .prompt-tip }

## 8. Native Ads

Native ads let you design the ad's appearance to match your app's look and feel. Instead of receiving a pre-rendered banner or full-screen creative, you receive individual components (headline, body, icon, media, call-to-action) and render them yourself.

### Add the Native Ad Layout

```xml
<!-- res/layout/native_ad_layout.xml -->
<com.google.android.gms.ads.nativead.NativeAdView
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:padding="8dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">

            <ImageView
                android:id="@+id/ad_app_icon"
                android:layout_width="40dp"
                android:layout_height="40dp" />

            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:orientation="vertical"
                android:paddingStart="8dp">

                <TextView
                    android:id="@+id/ad_headline"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textStyle="bold"
                    android:textSize="16sp" />

                <TextView
                    android:id="@+id/ad_advertiser"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textSize="12sp" />

            </LinearLayout>
        </LinearLayout>

        <com.google.android.gms.ads.nativead.MediaView
            android:id="@+id/ad_media"
            android:layout_width="match_parent"
            android:layout_height="200dp"
            android:layout_marginTop="8dp" />

        <TextView
            android:id="@+id/ad_body"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:textSize="14sp" />

        <Button
            android:id="@+id/ad_call_to_action"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_gravity="end"
            android:layout_marginTop="8dp" />

    </LinearLayout>
</com.google.android.gms.ads.nativead.NativeAdView>
```

### Load and Display the Native Ad

```java
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdOptions;
import com.google.android.gms.ads.nativead.NativeAdView;
import com.google.android.gms.ads.AdLoader;

public class FeedActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_feed);

        loadNativeAd();
    }

    private void loadNativeAd() {
        AdLoader adLoader = new AdLoader.Builder(this,
                "ca-app-pub-3940256099942544/2247696110")
            .forNativeAd(nativeAd -> populateNativeAdView(nativeAd))
            .withNativeAdOptions(new NativeAdOptions.Builder()
                .setAdChoicesPlacement(NativeAdOptions.ADCHOICES_TOP_RIGHT)
                .build())
            .build();

        adLoader.loadAd(new AdRequest.Builder().build());
    }

    private void populateNativeAdView(NativeAd nativeAd) {
        NativeAdView adView = (NativeAdView) getLayoutInflater()
            .inflate(R.layout.native_ad_layout, null);

        TextView headlineView = adView.findViewById(R.id.ad_headline);
        headlineView.setText(nativeAd.getHeadline());
        adView.setHeadlineView(headlineView);

        TextView bodyView = adView.findViewById(R.id.ad_body);
        bodyView.setText(nativeAd.getBody());
        adView.setBodyView(bodyView);

        Button ctaView = adView.findViewById(R.id.ad_call_to_action);
        ctaView.setText(nativeAd.getCallToAction());
        adView.setCallToActionView(ctaView);

        ImageView iconView = adView.findViewById(R.id.ad_app_icon);
        if (nativeAd.getIcon() != null) {
            iconView.setImageDrawable(nativeAd.getIcon().getDrawable());
        }
        adView.setIconView(iconView);

        com.google.android.gms.ads.nativead.MediaView mediaView =
            adView.findViewById(R.id.ad_media);
        adView.setMediaView(mediaView);

        TextView advertiserView = adView.findViewById(R.id.ad_advertiser);
        if (nativeAd.getAdvertiser() != null) {
            advertiserView.setText(nativeAd.getAdvertiser());
        }
        adView.setAdvertiserView(advertiserView);

        adView.setNativeAd(nativeAd);

        ViewGroup adContainer = findViewById(R.id.nativeAdContainer);
        adContainer.removeAllViews();
        adContainer.addView(adView);
    }
}
```

You **must** call the `setXxxView()` methods on the `NativeAdView` so the SDK can register click targets and render the AdChoices overlay. Simply setting text on the views is not enough.

> Native ads require significantly more development effort than other formats, but they outperform banners by 2--3x in both click-through rate and eCPM because they blend into your app's content. They are especially effective in feed-based or list-based UIs. Be mindful that Google policy requires the **AdChoices icon and "Ad" label** to remain clearly visible -- hiding or obscuring them will result in policy violations.
{: .prompt-info }

## 9. Testing Ads

### Use Google's Test Ad Unit IDs

Google provides dedicated test ad unit IDs that always return a test creative. **Never use production ad unit IDs during development** -- generating impressions on your own app violates AdMob policy and can get your account banned.

| Ad Format | Test Ad Unit ID |
|---|---|
| Banner | `ca-app-pub-3940256099942544/6300978111` |
| Adaptive Banner | `ca-app-pub-3940256099942544/9214589741` |
| Interstitial | `ca-app-pub-3940256099942544/1033173712` |
| Rewarded | `ca-app-pub-3940256099942544/5224354917` |
| Native Advanced | `ca-app-pub-3940256099942544/2247696110` |
| Rewarded Interstitial | `ca-app-pub-3940256099942544/5354046379` |
| App Open | `ca-app-pub-3940256099942544/9257395921` |

### Register Test Devices

When switching to your real ad unit IDs for integration testing, register your device as a test device so that real ads are served but impressions are not counted:

```java
MobileAds.initialize(this, initializationStatus -> {});

RequestConfiguration configuration = new RequestConfiguration.Builder()
    .setTestDeviceIds(Arrays.asList("YOUR_DEVICE_HASH_ID"))
    .build();
MobileAds.setRequestConfiguration(configuration);
```

Find your device hash ID in Logcat output when you first load a real ad. It appears in a message like:

```
I/Ads: Use RequestConfiguration.Builder.setTestDeviceIds(Arrays.asList("ABC123..."))
       to get test ads on this device.
```

### Ad Inspector

The **Ad Inspector** is a debugging overlay built into the SDK. It shows which ad sources are configured, their initialization status, and recent ad request/response details:

```java
MobileAds.openAdInspector(this, error -> {
    if (error != null) {
        Log.e("Ads", "Ad Inspector error: " + error.getMessage());
    }
});
```

Trigger this from a debug menu or a hidden gesture in your app during development.

> AdMob account bans are **permanent and difficult to appeal**. The most common causes are: tapping your own ads (even once during testing without test IDs), asking friends or family to click ads, and placing ads where accidental clicks are likely. Always use test ad unit IDs during development and never interact with live ads in your own app.
{: .prompt-danger }

## 10. Mediation

AdMob mediation lets you serve ads from multiple ad networks (Meta Audience Network, Unity Ads, AppLovin, ironSource, etc.) through a single integration point. The mediation layer selects the highest-paying ad source for each request, maximizing your revenue.

### Add Mediation Adapters

Each ad network requires its own adapter dependency. For example, to add Meta Audience Network:

```groovy
dependencies {
    implementation 'com.google.android.gms:play-services-ads:23.6.0'

    // Meta Audience Network mediation adapter
    implementation 'com.google.ads.mediation:facebook:6.18.0.0'

    // Unity Ads mediation adapter
    implementation 'com.google.ads.mediation:unity:4.12.4.0'
}
```

### Configure Mediation in AdMob

1. In the AdMob dashboard, navigate to **Mediation > Create mediation group**.
2. Select the ad format and platform.
3. Add ad sources (networks) and configure their app IDs and placement IDs.
4. Set the **mediation chain** order: use **optimized** mode (AdMob determines the best source dynamically) or **manual waterfall** (you set fixed eCPM floors).

> Enabling mediation typically increases ad revenue by **20--40%** compared to using AdMob alone, because multiple networks compete for each impression. Start with 2--3 major networks (Meta Audience Network, Unity Ads, and AppLovin are popular choices) and add more as your traffic grows. The marginal benefit of each additional network decreases, so there is a diminishing return after 5--6 sources.
{: .prompt-tip }

### Verify Adapter Initialization

Log the initialization status to confirm adapters loaded correctly:

```java
MobileAds.initialize(this, initializationStatus -> {
    Map<String, AdapterStatus> statusMap = initializationStatus.getAdapterStatusMap();
    for (Map.Entry<String, AdapterStatus> entry : statusMap.entrySet()) {
        Log.d("Ads", String.format("Adapter: %s | Status: %s",
            entry.getKey(),
            entry.getValue().getInitializationState()));
    }
});
```

## 11. User Consent and Privacy

### EU Consent (GDPR)

If your app is available in the European Economic Area, you must obtain consent before serving personalized ads. Google provides the **User Messaging Platform (UMP)** SDK, bundled with the Mobile Ads SDK since version 20.x.

```java
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

ConsentRequestParameters params = new ConsentRequestParameters.Builder()
    .setTagForUnderAgeOfConsent(false)
    .build();

ConsentInformation consentInformation = UserMessagingPlatform.getConsentInformation(this);

consentInformation.requestConsentInfoUpdate(this, params,
    () -> {
        if (consentInformation.isConsentFormAvailable()) {
            UserMessagingPlatform.loadConsentForm(this,
                consentForm -> consentForm.show(this, formError -> {
                    // Consent collected -- initialize ads
                    loadAds();
                }),
                formError -> Log.w("Consent", "Form load error: " + formError.getMessage())
            );
        } else {
            loadAds();
        }
    },
    formError -> Log.w("Consent", "Consent info update failed: " + formError.getMessage())
);
```

> **Important:** Do not load ads until consent has been obtained or determined to be unnecessary. Loading ads before consent in the EEA can result in policy violations.
{: .prompt-warning }

> When users decline personalized ads, you can still serve **non-personalized ads** by setting `npa=1` in the ad request extras. Non-personalized ads have a lower eCPM (typically 30--60% less), but they still generate revenue. Do not disable ads entirely just because a user declines consent -- switch to non-personalized mode instead.
{: .prompt-info }

### US State Privacy Laws (CCPA/CPRA)

For users in California and other US states with privacy laws, Google provides a **Restricted Data Processing** (RDP) flag:

```java
Bundle extras = new Bundle();
extras.putInt("rdp", 1);

AdRequest adRequest = new AdRequest.Builder()
    .addNetworkExtrasBundle(com.google.ads.mediation.admob.AdMobAdapter.class, extras)
    .build();
```

When RDP is enabled, Google limits how it uses the data collected from that ad request.

### Children's Privacy (COPPA)

If your app is directed at children under 13, you must tag ad requests accordingly:

```java
RequestConfiguration configuration = new RequestConfiguration.Builder()
    .setTagForChildDirectedTreatment(RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE)
    .setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_G)
    .build();
MobileAds.setRequestConfiguration(configuration);
```

This ensures only child-safe ads are served and disables interest-based advertising.

## 12. Google Play Policy Compliance

Getting ads technically working is only half the battle. Your app must also comply with Google Play's advertising policies to avoid removal.

### Mandatory Requirements

| Requirement | Details |
|---|---|
| **Ads declaration** | In the Play Console under **App content > Ads**, declare that your app contains ads |
| **Privacy policy** | Link a privacy policy URL in the Play Console and within the app. It must disclose ad-related data collection |
| **Data Safety section** | Declare data collected by ad SDKs (device ID, IP address, diagnostics). Google provides a [guide for AdMob](https://developers.google.com/admob/android/data-safety) |
| **Ad content rating** | Complete the IARC questionnaire and report that ads are present |
| **Consent for personalized ads** | Implement UMP or an equivalent consent mechanism for EEA users |

### Prohibited Behaviors

These will get your app rejected or your AdMob account suspended:

- **Clicking your own ads** or incentivizing users to click ads (e.g., "Click this ad to support us").
- **Placing ads that interfere with navigation** or mimic UI elements.
- **Showing interstitials during or immediately after app launch** without user interaction.
- **Placing ads next to interactive elements** in a way that causes accidental clicks.
- **Displaying ads in the background** when the app is not in the foreground.
- **Excessive ad density** -- filling the majority of the screen with ads.

## 13. ProGuard / R8 Rules for Ad SDKs

The Google Mobile Ads SDK bundles its own ProGuard rules via consumer rules, so in most cases no manual configuration is needed. However, if you use mediation adapters from third-party networks, check each SDK's documentation for required keep rules.

A general safety net for reflection-heavy ad SDKs:

```
# Keep Google Mobile Ads classes
-keep class com.google.android.gms.ads.** { *; }

# Keep mediation adapter classes
-keep class com.google.ads.mediation.** { *; }
```

If you encounter `ClassNotFoundException` or missing ad callbacks in release builds, the issue is almost certainly a missing keep rule.

## 14. Architecture Recommendations

### Centralize Ad Logic

Avoid scattering ad loading and display code across every Activity. Create a dedicated ad manager:

```java
public class AdManager {

    private static AdManager instance;
    private InterstitialAd interstitialAd;
    private long lastInterstitialShown = 0;
    private static final long MIN_INTERVAL_MS = 120_000; // 2 minutes

    private AdManager() {}

    public static synchronized AdManager getInstance() {
        if (instance == null) {
            instance = new AdManager();
        }
        return instance;
    }

    public void preloadInterstitial(Context context) {
        AdRequest adRequest = new AdRequest.Builder().build();
        InterstitialAd.load(context,
            BuildConfig.INTERSTITIAL_AD_UNIT_ID,
            adRequest,
            new InterstitialAdLoadCallback() {
                @Override
                public void onAdLoaded(InterstitialAd ad) {
                    interstitialAd = ad;
                }

                @Override
                public void onAdFailedToLoad(LoadAdError error) {
                    interstitialAd = null;
                }
            });
    }

    public void showInterstitialIfReady(Activity activity, Runnable onDismissed) {
        long now = System.currentTimeMillis();
        if (interstitialAd != null && (now - lastInterstitialShown) > MIN_INTERVAL_MS) {
            interstitialAd.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    lastInterstitialShown = System.currentTimeMillis();
                    interstitialAd = null;
                    preloadInterstitial(activity);
                    onDismissed.run();
                }
            });
            interstitialAd.show(activity);
        } else {
            onDismissed.run();
        }
    }
}
```

### Use BuildConfig for Ad Unit IDs

Keep ad unit IDs out of your Java code and layouts by defining them in `build.gradle`:

```groovy
android {
    buildTypes {
        debug {
            buildConfigField "String", "BANNER_AD_UNIT_ID",
                "\"ca-app-pub-3940256099942544/6300978111\""
            buildConfigField "String", "INTERSTITIAL_AD_UNIT_ID",
                "\"ca-app-pub-3940256099942544/1033173712\""
        }
        release {
            buildConfigField "String", "BANNER_AD_UNIT_ID",
                "\"ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ\""
            buildConfigField "String", "INTERSTITIAL_AD_UNIT_ID",
                "\"ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ\""
        }
    }
}
```

This guarantees that test IDs are used in debug builds and production IDs in release builds, with no risk of accidentally shipping test ads or generating invalid impressions.

> Consider offering an **"Remove Ads" in-app purchase** alongside your ad integration. A one-time purchase of $2.99--$4.99 can earn you more from a single power user than months of ad impressions from that same user. Implement it as a boolean flag in the `AdManager` -- when purchased, skip all ad loads entirely to reduce battery and data usage for paying users.
{: .prompt-tip }

## Common Pitfalls

| Pitfall | Solution |
|---|---|
| App crashes on launch with `IllegalStateException` | Missing `APPLICATION_ID` meta-data in `AndroidManifest.xml` |
| Ads not appearing but no errors in Logcat | Check that the ad unit ID matches the format. Test IDs start with `ca-app-pub-3940256099942544/` |
| `onAdFailedToLoad` with error code 3 (NO_FILL) | Normal during testing without test IDs. In production, it means no ad was available for that request |
| AdMob account suspended | You clicked your own ads, generated invalid traffic, or violated placement policies. Appeal through the AdMob dashboard |
| Interstitials blocking app navigation | Always provide a way to dismiss. Never show interstitials during loading screens or in rapid succession |
| Revenue is lower than expected | Enable mediation to compete multiple ad networks. Use adaptive banners. Place rewarded ads at high-engagement points |
| Consent form not showing | Ensure the UMP message is configured in the AdMob dashboard under **Privacy & messaging** |
| Ads not showing in release builds | Check ProGuard rules. Verify that the correct (production) ad unit IDs are being used |

## Summary

Integrating ads into an Android app is a multi-layered process that goes beyond dropping in an SDK:

1. **Set up AdMob** -- create an account, register your app, and create ad units.
2. **Add the SDK** -- include the `play-services-ads` dependency and configure the manifest with your App ID.
3. **Initialize early** -- call `MobileAds.initialize()` once in your app's startup path.
4. **Choose ad formats** -- banners for persistent visibility, interstitials for natural transitions, rewarded ads for opt-in engagement, and native ads for seamless integration.
5. **Test thoroughly** -- use Google's test ad unit IDs during development and register test devices for integration testing.
6. **Handle consent** -- implement UMP for GDPR, RDP for CCPA, and COPPA tags for children's apps.
7. **Comply with policy** -- declare ads in the Play Console, maintain a privacy policy, and avoid prohibited ad placements.
8. **Optimize revenue** -- enable mediation, use adaptive banners, and place high-value formats (rewarded) at engagement peaks.

Getting the technical integration right takes an afternoon. Getting the policy, consent, and user experience right is what separates a sustainable ad-supported app from one that gets flagged or uninstalled.

## Sources

- [Get Started with AdMob -- Android Developers](https://developers.google.com/admob/android/quick-start) -- Google
- [Banner Ads -- AdMob Android Guide](https://developers.google.com/admob/android/banner) -- Google
- [Interstitial Ads -- AdMob Android Guide](https://developers.google.com/admob/android/interstitial) -- Google
- [Rewarded Ads -- AdMob Android Guide](https://developers.google.com/admob/android/rewarded) -- Google
- [Native Ads Advanced -- AdMob Android Guide](https://developers.google.com/admob/android/native/start) -- Google
- [Mediation -- AdMob Android Guide](https://developers.google.com/admob/android/mediate) -- Google
- [UMP SDK -- User Messaging Platform](https://developers.google.com/admob/ump/android/quick-start) -- Google
- [Server-Side Verification -- AdMob](https://developers.google.com/admob/android/rewarded#server-side_verification_ssv_callbacks) -- Google
- [AdMob Data Safety Guide](https://developers.google.com/admob/android/data-safety) -- Google
- [Google Play Ads Policy](https://support.google.com/googleplay/android-developer/answer/9857753) -- Google
- [Google Mobile Ads SDK Release Notes](https://developers.google.com/admob/android/rel-notes) -- Google
