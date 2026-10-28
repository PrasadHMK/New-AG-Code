/**
*==============================================================================
* @File Name : rewardsSupportWidget.js
* @Description : Renders Crown Rewards responses inside the chat window.
* @Author : Prasad Yericherla
* @Created On : April 14, 2026
* @Last Modified By : Prasad Yericherla
* @Last Modified On : May 3, 2026
* @Modification Log :
*==============================================================================
**/
import { LightningElement, api } from 'lwc';
import createCaseFromWidget from '@salesforce/apex/Agentforce_Action_CreateCase.createCaseFromWidget';

const MISSING_POINTS_VIEW = 'missingPointsInteractive';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default class RewardsSupportWidget extends LightningElement {
_summaryMessage = '';
_responsePayload = '';
_value;

parsedPayload;
selectedMissingPointsPath = '';
inStoreEligibility = '';
inStoreReceiptAvailable = '';
interactiveErrorMessage = '';
inStoreCaseCreatedNumber = '';
inStoreFirstName = '';
inStoreLastName = '';
inStoreEmail = '';
submittedInStoreFirstName = '';
submittedInStoreLastName = '';
submittedInStoreEmail = '';
submittedReceiptFileName = '';
showInStoreCancelConfirmation = false;
isSubmittingInStoreCase = false;
uploadedFileName = '';
uploadedFileContentType = '';
uploadedFileBase64Data = '';
_interactiveStateKey = '';
fileErrorMessage = '';
MAX_FILE_SIZE = 4.5 * 1024 * 1024; // 4.5 MB in bytes

@api
get summaryMessage() {
return this._summaryMessage;
}

set summaryMessage(value) {
this._summaryMessage = value || '';
}

@api
get responsePayload() {
return this._responsePayload;
}

set responsePayload(value) {
this._responsePayload = value || '';
this.parsePayload();
}

@api
get value() {
return this._value;
}

set value(newValue) {
this._value = newValue;
this.parsePayload();
}

connectedCallback() {
this.resetInteractiveState();
}

parsePayload() {
const rawValue = this.rawValue;
const source = rawValue && typeof rawValue === 'object' ? rawValue : {};
const typed = source.renderedResponse && typeof source.renderedResponse === 'object'
? source.renderedResponse
: source;
const incomingPayload = typed.responsePayload !== undefined ? typed.responsePayload : this._responsePayload;
this.parsedPayload = null;

if (!incomingPayload) {
return;
}

try {
this.parsedPayload = JSON.parse(incomingPayload);
} catch (error) {
this.parsedPayload = {
view: 'error',
errorMessage: 'The Rewards response could not be rendered.'
};
}

const nextStateKey = this.interactiveStateKey;
if (this.isMissingPointsInteractive && this._interactiveStateKey !== nextStateKey) {
this.resetInteractiveState();
this.initializeMissingPointsEntryPath();
this._interactiveStateKey = nextStateKey;
} else if (this.isMissingPointsInteractive && !this.selectedMissingPointsPath) {
this.initializeMissingPointsEntryPath();
}
}

resetInteractiveState() {
this.selectedMissingPointsPath = '';
this.inStoreEligibility = '';
this.inStoreReceiptAvailable = '';
this.interactiveErrorMessage = '';
this.inStoreCaseCreatedNumber = '';
this.inStoreFirstName = '';
this.inStoreLastName = '';
this.inStoreEmail = '';
this.submittedInStoreFirstName = '';
this.submittedInStoreLastName = '';
this.submittedInStoreEmail = '';
this.submittedReceiptFileName = '';
this.showInStoreCancelConfirmation = false;
this.isSubmittingInStoreCase = false;
this.uploadedFileName = '';
this.uploadedFileContentType = '';
this.uploadedFileBase64Data = '';
}

initializeMissingPointsEntryPath() {
if (!this.isMissingPointsInteractive || !this.parsedPayload) {
return;
}
const entryPath = this.parsedPayload.entryPath;
if (entryPath === 'instore_form') {
this.selectedMissingPointsPath = 'inStore';
if (this.shouldRenderDirectInStoreCaseForm) {
this.inStoreEligibility = 'yes';
this.inStoreReceiptAvailable = 'yes';
}
} else if (entryPath === 'hallmark') {
this.selectedMissingPointsPath = 'hallmark';
}
}

get rawValue() {
return Array.isArray(this._value) ? this._value[0] : this._value;
}

get interactiveStateKey() {
return JSON.stringify({
view: this.viewName,
entryPath: this.parsedPayload ? this.parsedPayload.entryPath : null,
showStoreCaseForm: this.shouldRenderDirectInStoreCaseForm,
withinBusinessHours: this.interactiveWithinBusinessHours,
messagingSessionId: this.interactiveMessagingSessionId,
crownRewardsNumber: this.interactiveCrownRewardsNumber
});
}

get effectiveSummaryMessage() {
const typed = this.rawValue && this.rawValue.renderedResponse && typeof this.rawValue.renderedResponse === 'object'
? this.rawValue.renderedResponse
: this.rawValue;
return (typed && typed.summaryMessage) || this._summaryMessage;
}

get externalErrorMessage() {
const source = this.rawValue && typeof this.rawValue === 'object' ? this.rawValue : {};
const rendered = source.renderedResponse && typeof source.renderedResponse === 'object'
? source.renderedResponse
: {};
return source.errorMessage || rendered.errorMessage || null;
}

get hasExternalNarrative() {
return !!(this.effectiveSummaryMessage || this.externalErrorMessage);
}

get hasPayload() {
return this.isMissingPointsInteractive
|| (!this.suppressWidgetForTextOnlyView && (!!this.parsedPayload || !!this.effectiveSummaryMessage));
}

get viewName() {
return this.parsedPayload && this.parsedPayload.view
? this.parsedPayload.view
: null;
}

get isMissingPointsInteractive() {
return this.viewName === MISSING_POINTS_VIEW;
}

get rewards() {
return (this.parsedPayload && this.parsedPayload.rewards) || [];
}

get hasRewards() {
return this.rewards.length > 0;
}

get bonusOffers() {
return (this.parsedPayload && this.parsedPayload.bonusOffers) || [];
}

get hasBonusOffers() {
return this.bonusOffers.length > 0;
}

get rewardsCount() {
if (!this.parsedPayload) {
return 0;
}
if (this.parsedPayload.rewardsCount != null) {
return Number(this.parsedPayload.rewardsCount);
}
return this.rewards.length;
}

get bonusOffersCount() {
if (!this.parsedPayload) {
return 0;
}
if (this.parsedPayload.bonusOffersCount != null) {
return Number(this.parsedPayload.bonusOffersCount);
}
return this.bonusOffers.length;
}

get hasRewardsCount() {
return this.rewardsCount > 0;
}

get hasBonusOffersCount() {
return this.bonusOffersCount > 0;
}

get rewardChoices() {
return (this.parsedPayload && this.parsedPayload.rewardChoices) || [];
}

get hasRewardChoices() {
return this.viewName === 'rewardConversion' && this.rewardChoices.length > 0;
}

get showOverview() {
return this.parsedPayload && ['memberOverview', 'rewardsList', 'rewardConversion'].includes(this.viewName);
}

get hasMembershipTier() {
return this.parsedPayload && this.parsedPayload.membershipTier != null && this.parsedPayload.membershipTier !== '';
}

get hasPointsBalance() {
return this.parsedPayload && this.parsedPayload.pointsBalance != null;
}

get hasPointsToPlatinum() {
return this.parsedPayload
&& this.parsedPayload.pointsToPlatinum != null
&& Number(this.parsedPayload.pointsToPlatinum) > 0;
}

get membershipTier() {
return this.parsedPayload ? this.parsedPayload.membershipTier : null;
}

get pointsBalance() {
return this.parsedPayload ? this.parsedPayload.pointsBalance : null;
}

get pointsToPlatinum() {
return this.parsedPayload ? this.parsedPayload.pointsToPlatinum : null;
}

get showGuidance() {
return this.parsedPayload && this.viewName === 'rewardConversion' && this.rewardChoices.length > 0;
}

    get hasStructuredHero() {
        return this.showOverview || this.showGuidance;
    }

    get heroTitle() {
switch (this.viewName) {
case 'memberOverview':
return 'Crown Rewards Snapshot';
case 'rewardsList':
return 'Rewards And Bonus Offers';
case 'rewardConversion':
return 'Reward Conversion Guidance';
default:
return 'Crown Rewards';
}
}

get heroMessage() {
if (this.viewName === 'rewardConversion') {
return 'Rewards start with minimum 600 points.';
}
return null;
}

get rewardListItems() {
return this.rewards.map((label, index) => ({
key: `reward-${index}-${label}`,
label
}));
}

get bonusOfferListItems() {
return this.bonusOffers.map((label, index) => ({
key: `offer-${index}-${label}`,
label
}));
}

get showRewardsAndOffers() {
return this.viewName === 'memberOverview' && (this.hasRewards || this.hasBonusOffers);
}

get formattedCrownRewardsNumber() {
return this.parsedPayload ? this.parsedPayload.crownRewardsNumber : null;
}

get hasMembershipNumber() {
return !!this.formattedCrownRewardsNumber;
}

get rewardChoiceCards() {
const colorClasses = ['reward-choice-card--violet', 'reward-choice-card--blue', 'reward-choice-card--amber', 'reward-choice-card--rose'];
return this.rewardChoices.map((choice, index) => ({
key: String(choice),
label: `$${choice}`,
className: `reward-choice-card ${colorClasses[index % colorClasses.length]}`
}));
}

get suppressWidgetForTextOnlyView() {
return ['missingPoints', 'missingPointsText', 'accountUpdate', 'mergeMemberships', 'rewardConversion'].includes(this.viewName);
}

get interactiveHeaderMessage() {
if (this.shouldRenderDirectInStoreCaseForm) {
return 'Let’s proceed with creating a case for your missing points. Please follow the instructions provided.';
}
return (this.parsedPayload && this.parsedPayload.headerMessage)
|| 'Choose how the missing Crown Rewards points should be researched.';
}

get showMissingPointsHero() {
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath !== 'inStore';
}

get interactiveWithinBusinessHours() {
return !!(this.parsedPayload && this.parsedPayload.withinBusinessHours);
}

get interactiveMessagingSessionId() {
return (this.parsedPayload && this.parsedPayload.messagingSessionId) || '';
}

get interactiveCrownRewardsNumber() {
return (this.parsedPayload && this.parsedPayload.crownRewardsNumber) || '';
}

get currentMissingPointsPath() {
if (this.selectedMissingPointsPath) {
return this.selectedMissingPointsPath;
}
if (!this.isMissingPointsInteractive || !this.parsedPayload) {
return '';
}
if (this.parsedPayload.entryPath === 'instore_form') {
return 'inStore';
}
if (this.parsedPayload.entryPath === 'hallmark') {
return 'hallmark';
}
return '';
}

get showMissingPointsRootActions() {
return this.isMissingPointsInteractive && !this.currentMissingPointsPath;
}

get showMissingPointsCancelled() {
return this.isMissingPointsInteractive && this.currentMissingPointsPath === 'cancelled';
}

get showInStoreQuestion() {
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath === 'inStore'
&& !this.shouldRenderDirectInStoreCaseForm
&& !this.inStoreEligibility
&& !this.showInStoreWaitMessage;
}

get storePromptMessage() {
return (this.parsedPayload && this.parsedPayload.storePromptMessage)
|| 'Was the purchase made at least 72 hours ago?';
}

get showInStoreReceiptQuestion() {
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath === 'inStore'
&& !this.shouldRenderDirectInStoreCaseForm
&& this.inStoreEligibility === 'yes'
&& !this.inStoreReceiptAvailable
&& !this.showInStoreWaitMessage;
}

get storeReceiptPromptMessage() {
return (this.parsedPayload && this.parsedPayload.storeReceiptPromptMessage)
|| 'Do you have the receipt available to upload?';
}

get showInStoreCaseForm() {
if (this.shouldRenderDirectInStoreCaseForm) {
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath === 'inStore'
&& !this.inStoreCaseCreatedNumber
}
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath === 'inStore'
&& this.inStoreEligibility === 'yes'
&& this.inStoreReceiptAvailable === 'yes'
&& !this.inStoreCaseCreatedNumber
&& !this.showInStoreWaitMessage;
}

get showInStoreWaitMessage() {
if (this.shouldRenderDirectInStoreCaseForm) {
return false;
}
return this.isMissingPointsInteractive
&& this.currentMissingPointsPath === 'inStore'
&& (this.inStoreEligibility === 'no' || this.inStoreReceiptAvailable === 'no');
}

get storeWaitMessage() {
return (this.parsedPayload && this.parsedPayload.storeWaitMessage)
|| 'Crown Rewards points can only be researched after 72 hours have passed, and proof of purchase is required. Please come back once 72 hours have passed and you have the receipt available.';
}

get showHallmarkLookupForm() {
return false;
}

get hallmarkPromptMessage() {
return (this.parsedPayload && this.parsedPayload.hallmarkPromptMessage)
|| 'Please enter the order number, email address, or phone number in the chat to continue checking missing points for a Hallmark.com order.';
}

get shouldRenderDirectInStoreCaseForm() {
return !!(this.parsedPayload && this.parsedPayload.showStoreCaseForm);
}

get storeButtonLabel() {
return (this.parsedPayload && this.parsedPayload.storeButtonLabel) || 'In-Store purchase';
}

get hallmarkButtonLabel() {
return (this.parsedPayload && this.parsedPayload.hallmarkButtonLabel) || 'Hallmark.com order';
}

get cancelButtonLabel() {
return (this.parsedPayload && this.parsedPayload.cancelButtonLabel) || 'Cancel';
}

get cancelledMessage() {
return (this.parsedPayload && this.parsedPayload.cancelledMessage)
|| 'If you need further assistance, feel free to ask. Thank you for reaching out!';
}

get storeFormTitle() {
return (this.parsedPayload && this.parsedPayload.storeFormTitle) || 'Create Missing Points Case';
}

get storeFormMessage() {
return (this.parsedPayload && this.parsedPayload.storeFormMessage)
|| 'Great. I will need to gather a few details from you and then you will see the option to upload your photo.';
}

get showInteractiveError() {
return !!this.interactiveErrorMessage;
}

get showInStoreCaseCreated() {
return !!this.inStoreCaseCreatedNumber;
}

get confirmationFirstName() {
return this.submittedInStoreFirstName || this.inStoreFirstName || '';
}

get confirmationLastName() {
return this.submittedInStoreLastName || this.inStoreLastName || '';
}

get confirmationEmail() {
return this.submittedInStoreEmail || this.inStoreEmail || '';
}

get confirmationReceiptFileName() {
return this.submittedReceiptFileName || this.uploadedFileName || '';
}

get hasConfirmationReceipt() {
return !!this.confirmationReceiptFileName;
}

get hasFileError() {
return !!this.fileErrorMessage;
}

handleMissingPointsPathClick(event) {
this.interactiveErrorMessage = '';
this.selectedMissingPointsPath = event.currentTarget.dataset.path;
this.showInStoreCancelConfirmation = false;
}

handleInStoreEligibilityClick(event) {
this.interactiveErrorMessage = '';
this.showInStoreCancelConfirmation = false;
this.inStoreEligibility = event.currentTarget.dataset.answer;
if (this.inStoreEligibility !== 'yes') {
this.inStoreReceiptAvailable = '';
}
}

handleInStoreReceiptClick(event) {
this.interactiveErrorMessage = '';
this.showInStoreCancelConfirmation = false;
this.inStoreReceiptAvailable = event.currentTarget.dataset.answer;
}

handleResetMissingPointsFlow() {
this.resetInteractiveState();
this.initializeMissingPointsEntryPath();
this._interactiveStateKey = this.interactiveStateKey;
}

handleBackToInStoreQuestion() {
this.interactiveErrorMessage = '';
this.inStoreEligibility = '';
this.inStoreReceiptAvailable = '';
this.inStoreCaseCreatedNumber = '';
this.showInStoreCancelConfirmation = false;
this.uploadedFileName = '';
this.uploadedFileContentType = '';
this.uploadedFileBase64Data = '';
this.fileErrorMessage = '';
this.selectedMissingPointsPath = '';
}

handleBackToMainInStoreQuestion() {
this.handleBackToInStoreQuestion();
}

handleCancelMissingPointsFlow() {
this.resetInteractiveState();
this.selectedMissingPointsPath = 'cancelled';
this._interactiveStateKey = this.interactiveStateKey;
}

handleStoreFormInput(event) {
const fieldName = event.target.dataset.field;
if (!fieldName) {
return;
}
this[fieldName] = event.target.value;
}

handleClearInStoreCase() {
this.interactiveErrorMessage = '';
this.fileErrorMessage = '';
this.inStoreFirstName = '';
this.inStoreLastName = '';
this.inStoreEmail = '';
this.uploadedFileName = '';
this.uploadedFileContentType = '';
this.uploadedFileBase64Data = '';
    const fileInput = this.template.querySelector('lightning-input[type="file"]');
    if (fileInput) {
        fileInput.value = null;
    }
}

async handleUploadFile(event) {
const file = event.target.files && event.target.files[0];
this.interactiveErrorMessage = '';
if (!file) {
this.uploadedFileName = '';
this.uploadedFileContentType = '';
this.uploadedFileBase64Data = '';
return;
}
if (file.size > this.MAX_FILE_SIZE) {
const fileSizeMB = (file.size / (1024 * 1024)).toFixed(2);
this.fileErrorMessage = `File size exceeds the maximum limit of 4.5 MB. Selected file is ${fileSizeMB} MB.`;
this.uploadedFileName = '';
this.uploadedFileContentType = '';
this.uploadedFileBase64Data = '';
event.target.value = '';
return;
}

try {
const base64Data = await this.readFileAsBase64(file);
this.uploadedFileName = file.name;
this.uploadedFileContentType = file.type || 'application/octet-stream';
this.uploadedFileBase64Data = base64Data;
this.fileErrorMessage = ''; // Clear any previous error
} catch (error) {
this.interactiveErrorMessage = 'The receipt could not be read. Please try again.';
}
}

async handleSubmitInStoreCase() {
this.interactiveErrorMessage = '';
if (!this.inStoreFirstName || !this.inStoreLastName || !this.inStoreEmail) {
this.interactiveErrorMessage = 'First name, last name, and email are required.';
return;
}
if (!EMAIL_PATTERN.test(this.inStoreEmail.trim())) {
this.interactiveErrorMessage = 'Enter a valid email address.';
return;
}
if (!this.uploadedFileBase64Data) {
this.interactiveErrorMessage = 'Upload the receipt before submitting the case.';
return;
}
if (this.fileErrorMessage) {
this.interactiveErrorMessage = this.fileErrorMessage ;
return;
}

this.isSubmittingInStoreCase = true;
try {
const submittedFirstName = this.inStoreFirstName.trim();
const submittedLastName = this.inStoreLastName.trim();
const submittedEmail = this.inStoreEmail.trim();
const submittedReceiptFileName = this.uploadedFileName;
const response = await createCaseFromWidget({
requestJson: JSON.stringify({
caseComponentKey: 'MISSING_POINTS_IN_STORE_PURCHASE',
firstName: submittedFirstName,
lastName: submittedLastName,
contactEmail: submittedEmail,
description: 'Missing Crown Rewards points from an in-store purchase.',
withinBusinessHours: this.interactiveWithinBusinessHours,
messagingSessionId: this.interactiveMessagingSessionId,
broadGrouping: 'cr',
uploadFileName: submittedReceiptFileName,
uploadContentType: this.uploadedFileContentType,
uploadBase64Data: this.uploadedFileBase64Data
})
});
if (!response || response.caseCreated !== true) {
throw new Error(response && response.errorMessage ? response.errorMessage : 'Case creation failed.');
}
this.submittedInStoreFirstName = submittedFirstName;
this.submittedInStoreLastName = submittedLastName;
this.submittedInStoreEmail = submittedEmail;
this.submittedReceiptFileName = submittedReceiptFileName;
this.inStoreCaseCreatedNumber = response.caseNumber || '';
} catch (error) {
this.interactiveErrorMessage = this.resolveErrorMessage(error);
} finally {
this.isSubmittingInStoreCase = false;
}
}

readFileAsBase64(file) {
return new Promise((resolve, reject) => {
const reader = new FileReader();
reader.onload = () => {
const result = reader.result;
if (typeof result !== 'string' || result.indexOf(',') === -1) {
reject(new Error('Invalid file data.'));
return;
}
resolve(result.split(',')[1]);
};
reader.onerror = () => reject(reader.error || new Error('File read failed.'));
reader.readAsDataURL(file);
});
}

resolveErrorMessage(error) {
const bodyMessage = error && error.body && error.body.message;
const directMessage = error && error.message;
return bodyMessage || directMessage || 'Something went wrong. Please try again.';
}
}
