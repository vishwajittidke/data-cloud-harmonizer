import { LightningElement, track, wire } from 'lwc';
import fetchDashboardData from '@salesforce/apex/IdentityResolutionEngine.fetchDashboardData';
import runHarmonizationAura from '@salesforce/apex/IdentityResolutionEngine.runHarmonizationAura';
import resetDemo from '@salesforce/apex/IdentityResolutionEngine.resetDemo';
import injectMockData from '@salesforce/apex/IdentityResolutionEngine.injectMockData';
import { refreshApex } from '@salesforce/apex';

export default class DataCloudExplorer extends LightningElement {
    @track subscribers = [];
    @track posRecords = [];
    @track unifiedRecords = [];
    @track isProcessing = false;

    wiredDataResult;

    @wire(fetchDashboardData)
    wiredData(result) {
        this.wiredDataResult = result;
        if (result.data) {
            this.subscribers = result.data.subscribers || [];
            this.posRecords = result.data.pos || [];
            this.unifiedRecords = result.data.unified || [];
        } else if (result.error) {
            console.error('Error fetching data', result.error);
        }
    }

    get hasRawData() {
        return (this.subscribers.length > 0 || this.posRecords.length > 0);
    }

    get hasUnifiedData() {
        return this.unifiedRecords && this.unifiedRecords.length > 0;
    }

    handleInjectData() {
        this.isProcessing = true;
        injectMockData()
            .then(() => refreshApex(this.wiredDataResult))
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
    }

    handleReset() {
        this.isProcessing = true;
        resetDemo()
            .then(() => refreshApex(this.wiredDataResult))
            .catch(err => console.error(err))
            .finally(() => this.isProcessing = false);
    }

    handleRunHarmonization() {
        if (!this.hasRawData) {
            alert('Please inject messy data first!');
            return;
        }

        this.isProcessing = true;
        
        runHarmonizationAura()
            .then(() => {
                return refreshApex(this.wiredDataResult);
            })
            .catch(error => {
                console.error('Harmonization failed', error);
            })
            .finally(() => {
                setTimeout(() => {
                    this.isProcessing = false;
                }, 1200);
            });
    }
}
