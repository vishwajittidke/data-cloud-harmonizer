import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchDashboardData from '@salesforce/apex/IdentityResolutionEngine.fetchDashboardData';
import runHarmonizationAura from '@salesforce/apex/IdentityResolutionEngine.runHarmonizationAura';
import isBatchRunning from '@salesforce/apex/IdentityResolutionEngine.isBatchRunning';
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
        this.isProcessing = true;
        runHarmonizationAura()
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Engine Started',
                        message: 'Processing identities in the background... please wait.',
                        variant: 'info'
                    })
                );
                
                // Start polling the server to wait for BOTH batch jobs (Subscribers and POS) to finish
                this.pollBatchStatus();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }

    pollBatchStatus() {
        isBatchRunning()
            .then(isRunning => {
                if (isRunning) {
                    // If jobs are still processing in the queue, check again in 2 seconds
                    setTimeout(() => {
                        this.pollBatchStatus();
                    }, 2000);
                } else {
                    // All Batch jobs have finished! Refresh the UI dynamically!
                    refreshApex(this.wiredDataResult).then(() => {
                        this.isProcessing = false;
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'Data Harmonization Complete! UI Auto-Refreshed.',
                                variant: 'success'
                            })
                        );
                    });
                }
            })
            .catch(err => console.error(err));
    }
}
